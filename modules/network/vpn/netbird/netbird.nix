{config, lib, pkgs, ...}:

let
  cfg = config.host.network.vpn.netbird;
  sopsFile = "${config.host.configDir}/hosts/${config.host.network.dns.hostname}/secrets/netbird.yaml";
  tunnelNames = lib.attrNames cfg.tunnels;
  tunnelWithIndex = lib.imap0 (i: name: { inherit name i; }) tunnelNames;

  portForTunnel = tunnel: i:
    if tunnel.port != null
    then tunnel.port
    else 51820 + i;

  effectiveManagementUrl = tunnel:
    if tunnel.managementUrl != null then tunnel.managementUrl
    else cfg.managementUrl;

  effectiveAdminUrl = tunnel:
    if tunnel.adminUrl != null then tunnel.adminUrl
    else if cfg.adminUrl != null then cfg.adminUrl
    else effectiveManagementUrl tunnel;

  # Netbird config.json stores URLs as Go url.URL structs, not plain strings
  urlToGoStruct = urlStr:
    let
      parts = builtins.match "([a-zA-Z]+)://([^/]*)(/?.*)" urlStr;
    in {
      Scheme = builtins.elemAt parts 0;
      Opaque = "";
      User = null;
      Host = builtins.elemAt parts 1;
      Path = builtins.elemAt parts 2;
      RawPath = "";
      OmitHost = false;
      ForceQuery = false;
      RawQuery = "";
      Fragment = "";
      RawFragment = "";
    };
in
  with lib;
{
  options = {
    host.network.vpn.netbird = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables Netbird VPN client";
      };
      managementUrl = mkOption {
        default = null;
        type = with types; nullOr str;
        description = "Default management server URL applied to all tunnels";
      };
      adminUrl = mkOption {
        default = null;
        type = with types; nullOr str;
        description = "Default admin panel URL applied to all tunnels (defaults to managementUrl)";
      };
      useRoutingFeatures = mkOption {
        default = "client";
        type = with types; enum [ "none" "client" "server" "both" ];
        description = "Routing features mode";
      };
      logLevel = mkOption {
        default = "info";
        type = with types; enum [ "panic" "fatal" "error" "warn" "info" "debug" "trace" ];
        description = "Log level for Netbird daemons";
      };
      hardened = mkOption {
        default = true;
        type = with types; bool;
        description = "Run tunnel daemons as dedicated users with minimal permissions";
      };
      tunnels = mkOption {
        default = {};
        type = with types; attrsOf (submodule {
          options = {
            port = mkOption {
              default = null;
              type = with types; nullOr port;
              description = "WireGuard listen port (auto-assigned from 51820 if null)";
            };
            autoStart = mkOption {
              default = true;
              type = with types; bool;
              description = "Start this tunnel with the system";
            };
            setupKey = mkOption {
              default = true;
              type = with types; bool;
              description = "Enable automated login via SOPS-managed setup key";
            };
            managementUrl = mkOption {
              default = null;
              type = with types; nullOr str;
              description = "Management server URL override for this tunnel";
            };
            adminUrl = mkOption {
              default = null;
              type = with types; nullOr str;
              description = "Admin panel URL override for this tunnel";
            };
          };
        });
        description = "Named Netbird tunnels (one per network/management plane)";
      };
    };
  };

  config = mkIf cfg.enable {
    services.netbird = {
      useRoutingFeatures = lib.mkDefault cfg.useRoutingFeatures;
    };

    services.netbird.tunnels = lib.listToAttrs (map ({ name, i }:
      let
        tunnel = cfg.tunnels.${name};
        mgmtUrl = effectiveManagementUrl tunnel;
        admUrl = effectiveAdminUrl tunnel;
      in
      lib.nameValuePair name {
        port = portForTunnel tunnel i;
        hardened = cfg.hardened;
        autoStart = tunnel.autoStart;
        logLevel = cfg.logLevel;
        environment = lib.mkMerge [
          (lib.mkIf (mgmtUrl != null) { NB_MANAGEMENT_URL = mgmtUrl; })
          (lib.mkIf (admUrl != null) { NB_ADMIN_URL = admUrl; })
        ];
        config = lib.mkMerge [
          (lib.mkIf (mgmtUrl != null) { ManagementURL = urlToGoStruct mgmtUrl; })
          (lib.mkIf (admUrl != null) { AdminURL = urlToGoStruct admUrl; })
        ];
        login = lib.mkIf tunnel.setupKey {
          enable = true;
          setupKeyFile = config.sops.secrets."netbird/${name}/setup_key".path;
        };
      }
    ) tunnelWithIndex);

    systemd.services = lib.listToAttrs (map ({ name, i }:
      let
        tunnel = cfg.tunnels.${name};
        mgmtUrl = effectiveManagementUrl tunnel;
        admUrl = effectiveAdminUrl tunnel;
      in
      lib.nameValuePair "netbird-${name}" {
        restartTriggers = [
          mgmtUrl
          admUrl
          (portForTunnel tunnel i)
          cfg.logLevel
          cfg.hardened
          tunnel.autoStart
          tunnel.setupKey
        ];
      }
    ) tunnelWithIndex);

    sops.secrets = lib.mkMerge (lib.mapAttrsToList (name: tunnel:
      lib.mkIf (tunnel.setupKey && builtins.pathExists sopsFile) {
        "netbird/${name}/setup_key" = {
          inherit sopsFile;
          restartUnits = [ "netbird-${name}.service" ];
        } // lib.optionalAttrs cfg.hardened {
          owner = "netbird-${name}";
          group = "netbird-${name}";
        };
      }
    ) cfg.tunnels);

    security.polkit.extraConfig = lib.mkIf (cfg.hardened && cfg.dns) ''
      polkit.addRule(function(action, subject) {
        var actions = [
          "org.freedesktop.resolve1.revert",
          "org.freedesktop.resolve1.set-default-route",
          "org.freedesktop.resolve1.set-dns-servers",
          "org.freedesktop.resolve1.set-domains",
          "org.freedesktop.resolve1.set-dnssec",
        ];
        var users = ${builtins.toJSON (map (name: "netbird-${name}") tunnelNames)};
        if (actions.indexOf(action.id) >= 0 && users.indexOf(subject.user) >= 0) {
          return polkit.Result.YES;
        }
      });
    '';

    host.filesystem.impermanence.directories = lib.mkIf config.host.filesystem.impermanence.enable (
      lib.mapAttrsToList (name: _: "/var/lib/netbird-${name}") cfg.tunnels
    );
  };
}
