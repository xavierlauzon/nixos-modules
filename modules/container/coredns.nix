{config, lib, pkgs, ...}:

let
  container_name = "coredns";
  container_description = "Enables DNS Resolution";
  container_image_registry = "docker.io";
  container_image_name = "docker.io/nfrastack/coredns";
  container_image_tag = "latest";
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
        default = false;
        type = with types; bool;
        description = "Enable logshipping for this container";
      };
      monitor = mkOption {
        default = false;
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
        tcp = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable CoreDNS port binding with network detection";
          };
          host = mkOption {
            default = 53;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 53;
            type = with types; int;
            description = "Container port for CoreDNS";
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
        udp = {
          enable = mkOption {
            default = false;
            type = with types; bool;
            description = "Enable CoreDNS port binding with network detection";
          };
          host = mkOption {
            default = 53;
            type = with types; int;
            description = "Host port to bind to";
          };
          container = mkOption {
            default = 53;
            type = with types; int;
            description = "Container port for CoreDNS";
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
      hostname = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "Custom hostname for the container (overrides default if set)";
      };
      containerName = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "Custom container name (overrides default if set)";
      };
    };
  };

  config = mkIf cfg.enable {
    host.feature.virtualization.docker.containers."${container_name}" = {
      enable = mkDefault true;
      containerName = mkDefault (if cfg.containerName != null then cfg.containerName else "${container_name}");
      hostname = mkDefault cfg.hostname;

      image = {
        name = mkDefault cfg.image.name;
        tag = mkDefault cfg.image.tag;
        registry = mkDefault cfg.image.registry.host;
        pullOnStart = mkDefault cfg.image.update;
      };

      resources = {
        memory = {
          max = mkDefault "1.0G";
        };
      };

      ports =
        (if cfg.ports.tcp.enable then [
          {
            host = toString cfg.ports.tcp.host;
            container = toString cfg.ports.tcp.container;
            method = cfg.ports.tcp.method;
            excludeInterfaces = cfg.ports.tcp.excludeInterfaces;
            excludeInterfacePattern = cfg.ports.tcp.excludeInterfacePattern;
            zerotierNetwork = cfg.ports.tcp.zerotierNetwork;
            protocol = "tcp";
          }
        ] else []) ++
        (if cfg.ports.udp.enable then [
          {
            host = toString cfg.ports.udp.host;
            container = toString cfg.ports.udp.container;
            method = cfg.ports.udp.method;
            excludeInterfaces = cfg.ports.udp.excludeInterfaces;
            excludeInterfacePattern = cfg.ports.udp.excludeInterfacePattern;
            zerotierNetwork = cfg.ports.udp.zerotierNetwork;
            protocol = "udp";
          }
        ] else []);

      volumes = [
        {
          source = "/var/local/data/_system/${container_name}/data/";
          target = "/data";
          createIfMissing = mkDefault true;
          removeCOW = mkDefault true;
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
        "CONTAINER_ENABLE_MONITORING" = boolToString cfg.monitor;
        "CONTAINER_ENABLE_LOGSHIPPING" = boolToString cfg.logship;
      };

      secrets = {
        enable = mkDefault cfg.secrets.enable;
        autoDetect = mkDefault cfg.secrets.autoDetect;
        files = mkDefault cfg.secrets.files;
      };

      networking = {
        ip = mkDefault "172.19.153.153";  # Fixed IP for DNS
        networks = [
          "services"
        ];
        aliases = {
          default = mkDefault true;
          extra = mkDefault (
            let
              rawName = if cfg.containerName != null then cfg.containerName else "${container_name}";
              aliasName = lib.strings.removeSuffix "-app" rawName;
              hostAlias =
                if builtins.isAttrs config.host.network.dns.hostname
                then config.host.network.dns.hostname.${aliasName} or null
                else null;
              aliasesList = [ aliasName ] ++ (lib.optional (hostAlias != null) hostAlias);
            in
              aliasesList ++ (cfg.networking.aliases.extra or [])
          );
        };
      };
    };
  };
}