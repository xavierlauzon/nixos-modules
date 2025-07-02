{config, lib, pkgs, ...}:

let
  container_name = "openldap";
  container_description = "Enables OpenLDAP directory server container";
  container_image_registry = "docker.io";
  container_image_name = "docker.io/tiredofit/openldap-fusiondirectory";
  container_image_tag = "2.6-1.4";
  cfg = config.host.container.${container_name};
  hostname = config.host.network.dns.hostname;
in
  with lib;
{
  options = {
    host.container.${container_name} = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = container_description;
      };
      image = {
        name = mkOption {
          default = container_image_name;
          type = with types; str;
          description = "Image name";
        };
        tag = mkOption {
          default = container_image_tag;
          type = with types; str;
          description = "Image tag";
        };
        registry = {
          host = mkOption {
            default = container_image_registry;
            type = with types; str;
            description = "Image Registry";
          };
        };
        update = mkOption {
          default = true;
          type = with types; bool;
          description = "Pull image on each service start";
        };
      };
      logship = mkOption {
        default = true;
        type = with types; bool;
        description = "Enable logshipping for this container";
      };
      monitor = mkOption {
        default = true;
        type = with types; bool;
        description = "Enable monitoring for this container";
      };
      secrets = {
        enable = mkOption {
          default = true;
          type = with types; bool;
          description = "Enable SOPS secrets for this container";
        };
        autoDetect = mkOption {
          default = true;
          type = with types; bool;
          description = "Automatically detect and include common secret files if they exist";
        };
        files = mkOption {
          default = [ ];
          type = with types; listOf str;
          description = "List of additional secret file paths to include";
        };
      };
      ports = {
        ldap = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable LDAP port binding with network detection";
          };
          host = mkOption {
            default = 389;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 389;
            type = with types; int;
            description = "Container port for LDAP";
          };
          method = mkOption {
            default = "interface";
            type = with types; enum [ "interface" "address" "pattern" "zerotier" ];
            description = "IP resolution method";
          };
          excludeInterfaces = mkOption {
            default = [ "lo" ];
            type = with types; listOf types.str;
            description = "Interfaces to exclude";
          };
          excludeInterfacePattern = mkOption {
            default = "docker|veth|br-|enp|eth|wlan";
            type = with types; str;
            description = "Interface exclusion pattern";
          };
          zerotierNetwork = mkOption {
            default = "";
            type = with types; str;
            description = "ZeroTier network ID";
          };
        };
        ldaps = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable LDAPS port binding with network detection";
          };
          host = mkOption {
            default = 636;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 636;
            type = with types; int;
            description = "Container port for LDAPS";
          };
          method = mkOption {
            default = "interface";
            type = with types; enum [ "interface" "address" "pattern" "zerotier" ];
            description = "IP resolution method";
          };
          excludeInterfaces = mkOption {
            default = [ "lo" ];
            type = with types; listOf types.str;
            description = "Interfaces to exclude";
          };
          excludeInterfacePattern = mkOption {
            default = "docker|veth|br-|enp|eth|wlan";
            type = with types; str;
            description = "Interface exclusion pattern";
          };
          zerotierNetwork = mkOption {
            default = "";
            type = with types; str;
            description = "ZeroTier network ID";
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    host.feature.virtualization.docker.containers."${container_name}" = {
      enable = mkDefault true;
      containerName = mkDefault "${container_name}";

      image = {
        name = mkDefault cfg.image.name;
        tag = mkDefault cfg.image.tag;
        registry = mkDefault cfg.image.registry.host;
        pullOnStart = mkDefault cfg.image.update;
      };

      resources = {
        memory = {
          max = mkDefault "4G";
        };
      };

      ports =
        (if cfg.ports.ldap.enable then [
          {
            host = toString cfg.ports.ldap.host;
            container = toString cfg.ports.ldap.container;
            method = cfg.ports.ldap.method;
            excludeInterfaces = cfg.ports.ldap.excludeInterfaces;
            excludeInterfacePattern = cfg.ports.ldap.excludeInterfacePattern;
            zerotierNetwork = cfg.ports.ldap.zerotierNetwork;
          }
        ] else []) ++
        (if cfg.ports.ldaps.enable then [
          {
            host = toString cfg.ports.ldaps.host;
            container = toString cfg.ports.ldaps.container;
            method = cfg.ports.ldaps.method;
            excludeInterfaces = cfg.ports.ldaps.excludeInterfaces;
            excludeInterfacePattern = cfg.ports.ldaps.excludeInterfacePattern;
            zerotierNetwork = cfg.ports.ldaps.zerotierNetwork;
          }
        ] else []);

      hostname = mkDefault "${config.host.network.hostname}.${config.host.network.dns.domain
}";

      volumes = [
        {
          source = "/var/local/data/_system/${container_name}/asset/custom-plugins";
          target = "/assets/fusiondirectory-custom";
          createIfMissing = mkDefault true;
          permissions = mkDefault "755";
        }
        {
          source = "/var/local/data/_system/${container_name}/backup";
          target = "/data/backup";
          createIfMissing = mkDefault true;
          permissions = mkDefault "755";
        }
        {
          source = "/var/local/data/_system/${container_name}/certs";
          target = "/certs";
          createIfMissing = mkDefault true;
          permissions = mkDefault "755";
        }
        {
          source = "/var/local/data/_system/${container_name}/config";
          target = "/etc/openldap/slapd.d";
          createIfMissing = mkDefault true;
          permissions = mkDefault "755";
        }
        {
          source = "/var/local/data/_system/${container_name}/data";
          target = "/var/lib/openldap";
          createIfMissing = mkDefault true;
          permissions = mkDefault "755";
        }
        {
          source = "/var/local/data/_system/${container_name}/logs";
          target = "/logs";
          createIfMissing = mkDefault true;
          removeCOW = mkDefault true;
          permissions = mkDefault "755";
        }
      ];

      environment = {
        "TIMEZONE" = mkDefault config.time.timeZone;
        "CONTAINER_NAME" = mkDefault "${hostname}-${container_name}";
        "CONTAINER_ENABLE_MONITORING" = toString cfg.monitor;
        "CONTAINER_ENABLE_LOGSHIPPING" = toString cfg.logship;
      };

      secrets = {
        enable = mkDefault cfg.secrets.enable;
        autoDetect = mkDefault cfg.secrets.autoDetect;
        files = mkDefault cfg.secrets.files;
      };

      networking = {
        networks = [ "services" ];
      };
    };
  };
}