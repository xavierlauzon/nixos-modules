{ config, lib, pkgs, ... }:

with lib;

let
  wiredCfg = config.host.network.wired;
  bridgeCfgs = config.host.network.bridges or { };

  allBridgedInterfaces = concatMap (bridgeCfg: bridgeCfg.interfaces) (attrValues bridgeCfgs);
  unbridgedInterfaces = filter (ifName: !(elem ifName allBridgedInterfaces)) (attrNames wiredCfg.interfaces);

in {
  options = {
    host.network = {
      wired = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable wired network configuration.";
        };
        interfaces = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              type = mkOption {
                type = types.enum [ "static" "dynamic" ];
                default = "static";
                description = "IP address configuration type.";
              };
              ip = mkOption {
                type = types.str;
                default = null;
                description = "IPv4 address with subnet mask (e.g., '192.168.1.10/24').";
              };
              gateway = mkOption {
                type = types.str;
                default = null;
                description = "Gateway IP address.";
              };
              mac = mkOption {
                type = types.str;
                default = null;
                description = "MAC address to match for the interface.";
              };
            };
          });
          description = "Configuration for wired network interfaces.";
        };
      };
      bridges = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              default = "br0";
              description = "Name of the bridge device.";
            };
            interfaces = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "List of interface names to include in the bridge.";
            };
            type = mkOption {
              type = types.enum [ "static" "dynamic" ];
              default = "static";
              description = "IP address configuration type.";
            };
            ip = mkOption {
              type = types.str;
              default = null;
              description = "IPv4 address with subnet mask.";
            };
            gateway = mkOption {
              type = types.str;
              default = null;
              description = "Gateway IP address.";
            };
            mac = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Optional MAC address.";
            };
          };
        });
        default = { };
        description = "Configuration for network bridges.";
      };
    };
  };

  config = mkIf wiredCfg.enable {
    networking.useNetworkd = true;

    assertions =
      # Assertions for wired interfaces
      concatMap (pair:
        let name = pair.name;
            cfg = pair.value;
            missingIP = cfg.ip == null && cfg.type == "static";
            missingGW = cfg.gateway == null && cfg.type == "static";
            missingMAC = cfg.mac == null;
        in [
          { assertion = !missingIP; message = "Error: ${name}.ip is required when type is 'static'."; }
          { assertion = !missingGW; message = "Error: ${name}.gateway is required when type is 'static'."; }
          { assertion = !missingMAC; message = "Error: ${name}.mac is required."; }
        ]
      ) (mapAttrsToList (ifName: ifCfg: { name = "host.network.wired.interfaces.${ifName}"; value = ifCfg; }) wiredCfg.interfaces)
      # Assertions for the bridges
      ++ concatMap (pair:
        let
          name = pair.name;
          bridgeCfg = pair.value;
          missingIP = bridgeCfg.ip == null && bridgeCfg.type == "static";
          missingGW = bridgeCfg.gateway == null && bridgeCfg.type == "static";
        in [
          { assertion = !missingIP; message = "Error: ${name}.ip is required when type is 'static'."; }
          { assertion = !missingGW; message = "Error: ${name}.gateway is required when type is 'static'."; }
        ]
      ) (mapAttrsToList (name: bridgeCfg: { name = "host.network.bridges.${name}"; value = bridgeCfg; }) bridgeCfgs);

    systemd.network = {
      enable = true;

      # Netdev configuration for the bridges
      netdevs = builtins.listToAttrs (map (bridgeCfg:
        let
          name = bridgeCfg.name;
        in {
          name = "10-${name}";
          value = {
            netdevConfig = {
              Kind = "bridge";
              Name = name;
            } // optionalAttrs (bridgeCfg.mac != null) {
              MACAddress = bridgeCfg.mac;
            };
          };
        }
      ) (attrValues bridgeCfgs));

      networks = let

        # Networks for bridged interfaces
        bridgedNetworks = builtins.foldl' (acc: bridgeCfg:
          let
            bridgeName = bridgeCfg.name;
            interfaces = bridgeCfg.interfaces;
            interfaceNetworks = builtins.listToAttrs (map (ifName: {
              name = "10-${ifName}";
              value = {
                matchConfig = { Name = ifName; };
                networkConfig = { Bridge = bridgeName; };
                linkConfig = { RequiredForOnline = "yes"; };
              };
            }) interfaces);
          in acc // interfaceNetworks
        ) { } (attrValues bridgeCfgs);

        # Network for the bridge devices themselves
        bridgeNetwork = builtins.listToAttrs (map (bridgeCfg:
          let
            bridgeName = bridgeCfg.name;
          in {
            name = "20-${bridgeName}";
            value = {
              matchConfig = { Name = bridgeName; } // optionalAttrs (bridgeCfg.mac != null) { MACAddress = bridgeCfg.mac; };
              networkConfig = optionalAttrs (bridgeCfg.type == "dynamic") { DHCP = "yes"; };
              linkConfig = optionalAttrs (bridgeCfg.type == "static") { RequiredForOnline = "yes"; };
              address = mkIf (bridgeCfg.type == "static") [ bridgeCfg.ip ];
              routes = mkIf (bridgeCfg.type == "static") [ { Gateway = bridgeCfg.gateway; GatewayOnLink = true; } ];
            };
          }
        ) (attrValues bridgeCfgs));

        # Networks for unbridged interfaces
        unbridgedNetworks = builtins.listToAttrs (map (ifName:
          let
            ifCfg = wiredCfg.interfaces.${ifName};
          in {
            name = "10-${ifName}";
            value = {
              matchConfig = { Name = ifName; } // optionalAttrs (ifCfg.mac != null) { MACAddress = ifCfg.mac; };
              networkConfig = optionalAttrs (ifCfg.type == "dynamic") { DHCP = "yes"; };
              linkConfig = optionalAttrs (ifCfg.type == "static") { RequiredForOnline = "yes"; };
              address = mkIf (ifCfg.type == "static") [ ifCfg.ip ];
              routes = mkIf (ifCfg.type == "static") [ { Gateway = ifCfg.gateway; GatewayOnLink = true; } ];
            };
          }
        ) unbridgedInterfaces);

      in unbridgedNetworks // bridgedNetworks // bridgeNetwork;
    };
  };
}