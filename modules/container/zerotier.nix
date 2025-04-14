{config, lib, pkgs, ...}:

let
  container_name = "zerotier";
  container_description = "Enables ZeroTier VPN Container";
  container_image_registry = "docker.io";
  container_image_name = "zyclonite/zerotier";
  container_image_tag = "latest";
  cfg = config.host.container.${container_name};
  hostname = config.host.network.dns.hostname;
  activationScript = "system.activationScripts.docker_${container_name}";
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
        default = "true";
        type = with types; str;
        description = "Enable monitoring for this container";
      };
      monitor = mkOption {
        default = "true";
        type = with types; str;
        description = "Enable monitoring for this container";
      };
    };
  };

  config = mkIf cfg.enable {
    host.feature.virtualization.docker.containers."${container_name}" = {
      image = "${cfg.image.name}:${cfg.image.tag}";
      volumes = [
        "/var/local/data/_system/${container_name}/zerotier:/var/lib/zerotier-one"
      ];
      environment = {
        "TIMEZONE" = "America/Toronto";
        "CONTAINER_NAME" = "${hostname}-${container_name}";
        "CONTAINER_ENABLE_MONITORING" = cfg.monitor;
        "CONTAINER_ENABLE_LOGSHIPPING" = cfg.logship;
      };

      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--cap-add=SYS_ADMIN"
        "--device=/dev/net/tun"
        "--network-alias=${hostname}-zerotier"
      ];
      networks = [
        "services"
        "socket-proxy"
        "proxy"
      ];
      autoStart = mkDefault true;
      log-driver = mkDefault "local";
      login = {
        registry = cfg.image.registry.host;
      };
      pullonStart = cfg.image.update;
    };


    systemd.services."docker-${container_name}" = {
      preStart = ''
        if [ ! -d /var/local/data/_system/${container_name}/zerotier ]; then
            mkdir -p /var/local/data/_system/${container_name}/zerotier
            ${pkgs.e2fsprogs}/bin/chattr +C /var/local/data/_system/${container_name}/zerotier
        fi
      '';

      serviceConfig = {
        StandardOutput = "null";
        StandardError = "null";
      };
    };

  };
}