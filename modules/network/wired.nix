{ config, lib, pkgs, ... }:
with lib;
let
  wiredCfg = config.host.network.wired;
  bridgeCfgs = config.host.network.bridges or { };
  bondCfgs = config.host.network.bonds or { };
in {
  options = {
    host.network = {
      wired = {
        enable = mkEnableOption "Wired network configuration";
        interfaces = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              type = mkOption {
                type = types.enum [ "static" "dynamic" ];
                default = "static";
                description = ''
                  IP address configuration type.
                  - "static": Manually configure IP address and gateway
                  - "dynamic": Use DHCP to obtain configuration
                '';
                example = "static";
              };
              ip = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                  IPv4 address with subnet mask (CIDR notation).
                  Required when type is set to "static".
                '';
                example = "192.168.1.10/24";
              };
              gateway = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                  Gateway IP address.
                  Required when type is set to "static".
                '';
                example = "192.168.1.1";
              };
              mac = mkOption {
                type = types.str;
                description = ''
                  MAC address to match for the interface.
                  This is how the system identifies which physical interface to configure.
                '';
                example = "aa:bb:cc:dd:ee:ff";
              };
            };
          });
          default = { };
          description = ''
            Configuration for wired network interfaces.
            Define each interface by a logical name and provide its configuration.
            The attribute name will be used as the interface name.
          '';
          example = literalExpression ''
            {
              eth0 = {
                mac = "00:11:22:33:44:55";
                type = "static";
                ip = "192.168.1.50/24";
                gateway = "192.168.1.1";
              };
              internet0 = {
                mac = "aa:bb:cc:dd:ee:ff";
                type = "dynamic";
              };
            }
          '';
        };
      };
      bridges = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              default = "br0";
              description = ''
                Name of the bridge device.
              '';
              example = "br0";
            };
            interfaces = mkOption {
              type = types.listOf types.str;
              default = [];
              description = ''
                List of interface MAC addresses to include in the bridge.
                These must match MAC addresses defined in host.network.wired.interfaces.
                Interfaces cannot be part of both a bridge and a bond.
              '';
              example = [ "00:11:22:33:44:55" "aa:bb:cc:dd:ee:ff" ];
            };
            bondInterfaces = mkOption {
              type = types.listOf types.str;
              default = [];
              description = ''
                List of bond interface names to include in the bridge.
                These must match names defined in host.network.bonds.
              '';
              example = [ "bond0" "bond1" ];
            };
            type = mkOption {
              type = types.enum [ "static" "dynamic" ];
              default = "static";
              description = ''
                IP address configuration type for the bridge.
                - "static": Manually configure IP address and gateway
                - "dynamic": Use DHCP to obtain configuration
              '';
              example = "static";
            };
            ip = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                IPv4 address with subnet mask (CIDR notation) for the bridge.
                Required when type is set to "static".
              '';
              example = "192.168.1.10/24";
            };
            gateway = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Gateway IP address for the bridge.
                Required when type is set to "static".
              '';
              example = "192.168.1.1";
            };
            mac = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Optional MAC address for the bridge.
                If not specified, the system will auto-assign a MAC address.
              '';
              example = "aa:bb:cc:00:11:22";
            };
          };
        });
        default = { };
        description = ''
          Configuration for network bridges.
          Bridges connect multiple interfaces at layer 2.
        '';
        example = literalExpression ''
          {
            br0 = {
              interfaces = [ "00:11:22:33:44:55" "aa:bb:cc:dd:ee:ff" ];
              type = "static";
              ip = "192.168.1.10/24";
              gateway = "192.168.1.1";
            };
            br1 = {
              bondInterfaces = [ "bond0" ];
              type = "dynamic";
            };
          }
        '';
      };
      bonds = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              default = "bond0";
              description = ''
                Name of the bond device.
              '';
              example = "bond0";
            };
            interfaces = mkOption {
              type = types.listOf types.str;
              default = [];
              description = ''
                List of interface MAC addresses to include in the bond.
                These must match MAC addresses defined in host.network.wired.interfaces.
              '';
              example = [ "00:11:22:33:44:55" "aa:bb:cc:dd:ee:ff" ];
            };
            mode = mkOption {
              type = types.enum [
                "balance-rr" "active-backup" "balance-xor" "broadcast"
                "802.3ad" "balance-tlb" "balance-alb"
              ];
              default = "active-backup";
              description = ''
                The bonding mode to use:
                - balance-rr: Round-robin load balancing
                - active-backup: Failover - only one active interface
                - balance-xor: XOR policy for load balancing
                - broadcast: Broadcast transmit on all interfaces
                - 802.3ad: IEEE 802.3ad Link Aggregation (requires switch support)
                - balance-tlb: Adaptive transmit load balancing
                - balance-alb: Adaptive load balancing
              '';
              example = "active-backup";
            };
            primaryInterface = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Primary interface MAC address for active-backup mode.
                Must be one of the MAC addresses listed in the interfaces option.
              '';
              example = "00:11:22:33:44:55";
            };
            type = mkOption {
              type = types.enum [ "static" "dynamic" ];
              default = "static";
              description = ''
                IP address configuration type for the bond.
                Only applicable if the bond is not part of a bridge.
                - "static": Manually configure IP address and gateway
                - "dynamic": Use DHCP to obtain configuration
              '';
              example = "static";
            };
            ip = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                IPv4 address with subnet mask for the bond.
                Required when type is "static" and the bond is not part of a bridge.
              '';
              example = "192.168.1.10/24";
            };
            gateway = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Gateway IP address for the bond.
                Required when type is "static" and the bond is not part of a bridge.
              '';
              example = "192.168.1.1";
            };
            mac = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Optional MAC address for the bond.
                If not specified, the system will auto-assign a MAC address.
              '';
              example = "aa:bb:cc:00:11:22";
            };
            miimonFreq = mkOption {
              type = types.int;
              default = 100;
              description = ''
                MII link monitoring frequency in milliseconds.
                Determines how often the link state is checked.
              '';
              example = 100;
            };
            downDelay = mkOption {
              type = types.int;
              default = 200;
              description = ''
                Time in milliseconds to wait before disabling a slave after link failure.
                This prevents flapping during short link disruptions.
              '';
              example = 200;
            };
            upDelay = mkOption {
              type = types.int;
              default = 200;
              description = ''
                Time in milliseconds to wait before enabling a slave after link recovery.
                This prevents flapping during short link disruptions.
              '';
              example = 200;
            };
          };
        });
        default = { };
        description = ''
          Configuration for network bonding.
          Bonds combine multiple interfaces into a single logical interface for
          redundancy, load balancing, or both.
        '';
        example = literalExpression ''
          {
            bond0 = {
              interfaces = [ "00:11:22:33:44:55" "aa:bb:cc:dd:ee:ff" ];
              mode = "active-backup";
              primaryInterface = "00:11:22:33:44:55";
              type = "static";
              ip = "192.168.1.10/24";
              gateway = "192.168.1.1";
            };
          }
        '';
      };
    };
  };

  config = mkIf wiredCfg.enable (
    let
      # Helper functions for common operations
      formatMac = mac: replaceStrings [":" "-"] ["" ""] mac;

      # Type validation helpers
      validateStaticConfig = name: cfg:
        let
          missingIP = cfg.ip == null && cfg.type == "static";
          missingGW = cfg.gateway == null && cfg.type == "static";
        in [
          { assertion = !missingIP; message = "Error: ${name}.ip is required when type is 'static'."; }
          { assertion = !missingGW; message = "Error: ${name}.gateway is required when type is 'static'."; }
        ];

      # Get all MAC addresses of interfaces that are part of bridges or bonds
      allBridgedMacs = concatMap (bridgeCfg: bridgeCfg.interfaces) (attrValues bridgeCfgs);
      allBondedMacs = concatMap (bondCfg: bondCfg.interfaces) (attrValues bondCfgs);

      # Get all bond names that are part of bridges
      allBridgedBonds = concatMap (bridgeCfg: bridgeCfg.bondInterfaces) (attrValues bridgeCfgs);

      # Function to convert attrsOf interfaces to a list with both name and values
      interfacesWithNames = mapAttrsToList (name: value: { inherit name; inherit value; }) wiredCfg.interfaces;

      # Filter interfaces that are neither part of a bridge nor a bond
      unbridgedInterfaces = filter (ifData:
        !(elem ifData.value.mac allBridgedMacs || elem ifData.value.mac allBondedMacs)
      ) interfacesWithNames;

      # Get all bonds that are not part of any bridge
      unbridgedBonds = filter (bondCfg:
        !(elem bondCfg.name allBridgedBonds)
      ) (attrValues bondCfgs);

      # Get all known interface MACs to ensure each is configured only once
      allInterfaceMacs = map (ifData: ifData.value.mac) interfacesWithNames;

      # Check for duplicate MACs
      hasDuplicateMacs = length allInterfaceMacs != length (unique allInterfaceMacs);

      # Network configuration helpers
      makeStaticNetworkConfig = cfg: {
        networkConfig = optionalAttrs (cfg.type == "dynamic") { DHCP = "yes"; };
        address = mkIf (cfg.type == "static") [ cfg.ip ];
        routes = mkIf (cfg.type == "static") [ { Gateway = cfg.gateway; GatewayOnLink = true; } ];
      };
      makeMacMatchConfig = mac: { matchConfig = { MACAddress = mac; }; };
      makeNameMatchConfig = name: { matchConfig = { Name = name; }; };
    in {
      networking.useNetworkd = true;
      systemd.network = {
        enable = true;

        # NETWORK DEVICE DEFINITIONS
        # =========================
        # This section defines the virtual network devices: bonds and bridges
        # The configuration sequence is important:
        # 1. Bond devices (prefix 10-) must be created before bridges
        # 2. Bridge devices (prefix 20-) depend on bonds and physical interfaces
        netdevs =
          # Bond netdev definitions (prefix 10-)
          builtins.listToAttrs (map (bondCfg:
            let name = bondCfg.name;
            in {
              name = "10-${name}";
              value = {
                netdevConfig = {
                  Kind = "bond";
                  Name = name;
                } // optionalAttrs (bondCfg.mac != null) {
                  MACAddress = bondCfg.mac;
                };
                bondConfig = {
                  Mode = bondCfg.mode;
                  MIIMonitorSec = toString (bondCfg.miimonFreq / 1000);
                  UpDelaySec = toString (bondCfg.upDelay / 1000);
                  DownDelaySec = toString (bondCfg.downDelay / 1000);
                } // (if bondCfg.primaryInterface != null then {
                  PrimaryReselectPolicy = "always";
                } else {});
              };
            }
          ) (attrValues bondCfgs))

          # Bridge netdev definitions (prefix 20-)
          // builtins.listToAttrs (map (bridgeCfg: {
              name = "20-${bridgeCfg.name}";
              value = {
                netdevConfig = {
                  Kind = "bridge";
                  Name = bridgeCfg.name;
                } // optionalAttrs (bridgeCfg.mac != null) {
                  MACAddress = bridgeCfg.mac;
                };
              };
            }) (attrValues bridgeCfgs));

        # NETWORK CONFIGURATIONS
        # ====================
        # This section defines how the network interfaces connect and behave
        # The configuration order is important:
        # 10-: Physical interfaces and bond members (lowest level)
        # 30-: Bond devices (combine physical interfaces)
        # 40-: Bridge members (connections to bridge)
        # 50-: Bridge devices (highest level, provides final IP)
        networks = let
          # 10-: Bond member configurations
          # Connect physical interfaces to bonds based on MAC address
          bondedInterfaceNetworks = builtins.foldl' (acc: bondCfg:
            let
              bondName = bondCfg.name;
              primaryMAC = bondCfg.primaryInterface;
              interfaceNetworks = builtins.listToAttrs (map (mac: {
                name = "10-bond-member-${formatMac mac}";
                value = recursiveUpdate (makeMacMatchConfig mac) {
                  networkConfig = { Bond = bondName; };
                  linkConfig = {
                    PrimarySlave = if mac == primaryMAC then "yes" else "no";
                  };
                };
              }) bondCfg.interfaces);
            in acc // interfaceNetworks
          ) { } (attrValues bondCfgs);

          # 10-: Standalone interface configurations
          # Direct IP configuration for interfaces not in bonds or bridges
          unbridgedNetworks = builtins.listToAttrs (map (ifData: {
              name = "10-${ifData.name}";
              value = recursiveUpdate
                (makeMacMatchConfig ifData.value.mac)
                (makeStaticNetworkConfig ifData.value) // {
                  linkConfig = {
                    Name = ifData.name; # Use attribute name as interface name
                  };
                };
            }) unbridgedInterfaces);

          # 30-: Bond device configurations
          # Configure bonds and their IP settings (if not in bridges)
          unbridgedBondNetworks = builtins.listToAttrs (map (bondCfg: {
              name = "30-${bondCfg.name}";
              value = recursiveUpdate
                (makeNameMatchConfig bondCfg.name)
                (if elem bondCfg.name allBridgedBonds
                 # Bridged bonds don't need IP config
                 then { networkConfig.ConfigureWithoutCarrier = "yes"; }
                 # Unbridged bonds need IP config
                 else makeStaticNetworkConfig bondCfg);
            }) (attrValues bondCfgs));

          # 40-: Bond-to-bridge connections
          # Connect bond devices to bridges
          bondToBridgeNetworks = builtins.foldl' (acc: bridgeCfg:
            let
              bridgeName = bridgeCfg.name;
              bondNetworks = builtins.listToAttrs (map (bondName: {
                name = "40-bridge-bond-${bondName}";
                value = recursiveUpdate (makeNameMatchConfig bondName) {
                  networkConfig = { Bridge = bridgeName; };
                };
              }) bridgeCfg.bondInterfaces);
            in acc // bondNetworks
          ) { } (attrValues bridgeCfgs);

          # 40-: Interface-to-bridge connections
          # Connect physical interfaces directly to bridges
          bridgedNetworks = builtins.foldl' (acc: bridgeCfg:
            let
              bridgeName = bridgeCfg.name;
              interfaceNetworks = builtins.listToAttrs (map (mac: {
                name = "40-bridge-member-${formatMac mac}";
                value = recursiveUpdate (makeMacMatchConfig mac) {
                  networkConfig = { Bridge = bridgeName; };
                };
              }) bridgeCfg.interfaces);
            in acc // interfaceNetworks
          ) { } (attrValues bridgeCfgs);

          # 50-: Bridge device configurations
          # Configure bridges and their IP settings
          bridgeNetworks = builtins.listToAttrs (map (bridgeCfg: {
              name = "50-${bridgeCfg.name}";
              value = recursiveUpdate
                (makeNameMatchConfig bridgeCfg.name)
                (makeStaticNetworkConfig bridgeCfg);
            }) (attrValues bridgeCfgs));

        in unbridgedNetworks // bondedInterfaceNetworks // unbridgedBondNetworks //
           bondToBridgeNetworks // bridgedNetworks // bridgeNetworks;
      };

      assertions = [
        # Base assertion to check for duplicate MAC addresses
        {
          assertion = !hasDuplicateMacs;
          message = "Error: Duplicate MAC addresses found in network interfaces configuration.";
        }
      ]
      # Assertions for wired interfaces
      ++ concatMap (pair:
          let name = pair.name;
              cfg = pair.value;
              missingMAC = cfg.mac == null;
          in validateStaticConfig "host.network.wired.interfaces.${name}" cfg ++ [
            {
              assertion = !missingMAC;
              message = "Error: host.network.wired.interfaces.${name}.mac is required.";
            }
          ]
        ) (mapAttrsToList nameValuePair wiredCfg.interfaces)

      # Assertions for bridges
      ++ concatMap (pair:
          let
            name = pair.name;
            bridgeCfg = pair.value;
            emptyInterfaces = bridgeCfg.interfaces == [] && bridgeCfg.bondInterfaces == [];
            # Check that specified bond names actually exist
            invalidBonds = filter (bondName: !hasAttr bondName bondCfgs) bridgeCfg.bondInterfaces;
          in validateStaticConfig "host.network.bridges.${name}" bridgeCfg ++ [
            {
              assertion = !emptyInterfaces;
              message = "Error: Bridge ${name} must have at least one interface or bond.";
            }
            {
              assertion = invalidBonds == [];
              message = "Error: Bridge ${name} references non-existent bond(s): ${toString invalidBonds}.";
            }
          ]
        ) (mapAttrsToList nameValuePair bridgeCfgs)

      # Assertions for bonds
      ++ concatMap (pair:
          let
            name = pair.name;
            bondCfg = pair.value;
            isBridged = elem name allBridgedBonds;
            skipIPCheck = isBridged; # Skip IP checks if bond is in a bridge
            emptyInterfaces = bondCfg.interfaces == [];
            isPrimaryMACValid = bondCfg.primaryInterface == null ||
                                elem bondCfg.primaryInterface bondCfg.interfaces;
          in (if skipIPCheck then [] else validateStaticConfig "host.network.bonds.${name}" bondCfg) ++ [
            {
              assertion = !emptyInterfaces;
              message = "Error: Bond ${name} must have at least one interface.";
            }
            {
              assertion = isPrimaryMACValid;
              message = "Error: ${name}.primaryInterface must be one of the MAC addresses in interfaces.";
            }
          ]
        ) (mapAttrsToList nameValuePair bondCfgs);
    }
  );
}