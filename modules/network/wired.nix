{ config, lib, pkgs, ... }:
with lib;
let
  wiredCfg = config.host.network.wired;
  bridgeCfgs = config.host.network.bridges or { };
  bondCfgs = config.host.network.bonds or { };

  # Common network options for both IPv4 and IPv6
  mkNetworkOptions = type: {
    enable = mkEnableOption "${type} support";
    type = mkOption {
      type = types.enum [ "static" "dynamic" ] // (if type == "ipv6" then { "slaac" = null; } else {});
      default = if type == "ipv6" then "slaac" else "static";
      description = "${type} configuration method";
      example = "static";
    };
    addresses = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of ${type} addresses with prefix length";
      example = if type == "ipv6"
                then [ "2001:db8::1/64" ]
                else [ "192.168.1.10/24" ];
    };
    gateway = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "${type} default gateway";
      example = if type == "ipv6"
                then "2001:db8::1"
                else "192.168.1.1";
    };
  } // (if type == "ipv6" then {
    acceptRA = mkOption {
      type = types.bool;
      default = true;
      description = "Accept Router Advertisements (needed for SLAAC)";
    };
  } else {});

  # Create options for interface types
  mkInterfaceOptions = {
    mac = mkOption {
      type = types.str;
      description = "MAC address to match for this interface";
      example = "aa:bb:cc:dd:ee:ff";
    };

    ipv4 = mkNetworkOptions "ipv4";
    ipv6 = mkNetworkOptions "ipv6";
  };
  # Create options for bridges
  mkBridgeOptions = {
    name = mkOption {
      type = types.str;
      default = "br0";
      description = "Name for the bridge device";
    };
    interfaces = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "MAC addresses of interfaces to include in the bridge";
      example = [ "00:11:22:33:44:55" ];
    };
    bondInterfaces = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Bond interfaces to include in the bridge";
      example = [ "bond0" ];
    };
    mac = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional MAC address for the bridge";
      example = "aa:bb:cc:00:11:22";
    };
    ipv4 = mkNetworkOptions "ipv4";
    ipv6 = mkNetworkOptions "ipv6";
  };

  # Create options for bonds
  mkBondOptions = {
    name = mkOption {
      type = types.str;
      default = "bond0";
      description = "Name for the bond device";
    };
    interfaces = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "MAC addresses of interfaces to include in the bond";
      example = [ "00:11:22:33:44:55" "aa:bb:cc:dd:ee:ff" ];
    };
    mode = mkOption {
      type = types.enum [
        "balance-rr" "active-backup" "balance-xor" "broadcast"
        "802.3ad" "balance-tlb" "balance-alb"
      ];
      default = "active-backup";
      description = "Bonding mode";
      example = "active-backup";
    };
    primaryInterface = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "MAC of primary interface for active-backup mode";
      example = "00:11:22:33:44:55";
    };
    mac = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional MAC address for the bond";
      example = "aa:bb:cc:00:11:22";
    };
    # Bond monitoring options
    miimonFreq = mkOption {
      type = types.int;
      default = 100;
      description = "Link monitoring frequency (ms)";
      example = 100;
    };
    downDelay = mkOption {
      type = types.int;
      default = 200;
      description = "Delay before disabling a failing link (ms)";
      example = 200;
    };
    upDelay = mkOption {
      type = types.int;
      default = 200;
      description = "Delay before enabling a recovered link (ms)";
      example = 200;
    };
    ipv4 = mkNetworkOptions "ipv4";
    ipv6 = mkNetworkOptions "ipv6";
  };
in {
  options = {
    host.network = {
      wired = {
        enable = mkEnableOption "wired networking";
        dhcp = {
          enable = mkEnableOption "DHCP for all unconfigured ethernet interfaces";
          v4 = mkOption {
            type = types.bool;
            default = true;
            description = "Enable DHCPv4 for unconfigured interfaces";
          };
          v6 = mkOption {
            type = types.bool;
            default = false;
            description = "Enable DHCPv6 for unconfigured interfaces";
          };
        };
        interfaces = mkOption {
          type = types.attrsOf (types.submodule { options = mkInterfaceOptions; });
          default = {};
          description = "Network interface configurations";
          example = literalExpression ''
            {
              eth0 = {
                mac = "00:11:22:33:44:55";
                ipv4 = {
                  type = "static";
                  addresses = [ "192.168.1.50/24" ];
                  gateway = "192.168.1.1";
                };
                ipv6 = {
                  enable = true;
                  type = "static";
                  addresses = [ "2001:db8::50/64" ];
                  gateway = "2001:db8::1";
                };
              };
            }
          '';
        };
      };
      bridges = mkOption {
        type = types.attrsOf (types.submodule { options = mkBridgeOptions; });
        default = {};
        description = "Network bridge configurations";
        example = literalExpression ''
          {
            br0 = {
              interfaces = [ "00:11:22:33:44:55" ];
              ipv4 = {
                type = "static";
                addresses = [ "192.168.1.10/24" ];
                gateway = "192.168.1.1";
              };
              ipv6.enable = true;
              ipv6.addresses = [ "2001:db8::10/64" ];
            };
          }
        '';
      };
      bonds = mkOption {
        type = types.attrsOf (types.submodule { options = mkBondOptions; });
        default = {};
        description = "Network bond configurations";
        example = literalExpression ''
          {
            bond0 = {
              interfaces = [ "00:11:22:33:44:55" "aa:bb:cc:dd:ee:ff" ];
              mode = "active-backup";
              primaryInterface = "00:11:22:33:44:55";
              ipv4 = {
                type = "static";
                addresses = [ "192.168.1.10/24" ];
                gateway = "192.168.1.1";
              };
            };
          }
        '';
      };
    };
  };

  config = mkIf wiredCfg.enable (
    let
      # Helper functions
      formatMac = mac: replaceStrings [":" "-"] ["" ""] mac;

      # Validation helper for IP configuration
      validateIPConfig = ipVersion: name: cfg:
        let
          ipEnabled = cfg.${ipVersion}.enable or false;
          isStatic = ipEnabled && cfg.${ipVersion}.type == "static";
          hasAddresses = cfg.${ipVersion}.addresses != [];
          hasGateway = cfg.${ipVersion}.gateway != null;
        in [
          {
            assertion = !(isStatic && !hasAddresses);
            message = "${name}: ${ipVersion} addresses required for static configuration";
          }
          {
            assertion = !(isStatic && !hasGateway);
            message = "${name}: ${ipVersion} gateway required for static configuration";
          }
        ];

      # Collect configuration data
      allBridgedMacs = concatMap (b: b.interfaces) (attrValues bridgeCfgs);
      allBondedMacs = concatMap (b: b.interfaces) (attrValues bondCfgs);
      allBridgedBonds = concatMap (b: b.bondInterfaces) (attrValues bridgeCfgs);

      interfacesWithNames = mapAttrsToList (name: value: { inherit name; inherit value; }) wiredCfg.interfaces;
      unbridgedInterfaces = filter (ifData:
        !(elem ifData.value.mac allBridgedMacs || elem ifData.value.mac allBondedMacs)
      ) interfacesWithNames;

      unbridgedBonds = filter (bondCfg: !(elem bondCfg.name allBridgedBonds)) (attrValues bondCfgs);
      allInterfaceMacs = map (ifData: ifData.value.mac) interfacesWithNames;
      hasDuplicateMacs = length allInterfaceMacs != length (unique allInterfaceMacs);

      # Generate network configuration
      makeNetworkConfig = cfg: {
        networkConfig =
          # IPv4 configuration
          (if cfg.ipv4.enable or true then
            if cfg.ipv4.type == "dynamic"
            then { DHCP = "ipv4"; }
            else {}
          else {})

          # IPv6 configuration
          // (if cfg.ipv6.enable or false then {
            IPv6AcceptRA = if cfg.ipv6.acceptRA then "yes" else "no";
            DHCP = let
              v4Dhcp = (cfg.ipv4.enable or true) && cfg.ipv4.type == "dynamic";
              v6Dhcp = cfg.ipv6.type == "dynamic";
            in
              if v4Dhcp && v6Dhcp then "yes"
              else if v4Dhcp then "ipv4"
              else if v6Dhcp then "ipv6"
              else "no";
          } else {});

        # All IP addresses (IPv4 + IPv6)
        address =
          (if (cfg.ipv4.enable or true) && cfg.ipv4.type == "static"
           then cfg.ipv4.addresses else []) ++
          (if (cfg.ipv6.enable or false) && cfg.ipv6.type == "static"
           then cfg.ipv6.addresses else []);

        # All routes (IPv4 + IPv6)
        routes =
          (if (cfg.ipv4.enable or true) && cfg.ipv4.type == "static" && cfg.ipv4.gateway != null
           then [{ Gateway = cfg.ipv4.gateway; GatewayOnLink = true; }] else []) ++
          (if (cfg.ipv6.enable or false) && cfg.ipv6.type == "static" && cfg.ipv6.gateway != null
           then [{ Gateway = cfg.ipv6.gateway; GatewayOnLink = true; }] else []);
      };

      # Matching helpers
      makeMacMatchConfig = mac: { matchConfig = { MACAddress = mac; }; };
      makeNameMatchConfig = name: { matchConfig = { Name = name; }; };

      # DHCP configuration
      defaultDhcpEnabled = wiredCfg.dhcp.enable;
      dhcpV4Enabled = defaultDhcpEnabled && wiredCfg.dhcp.v4;
      dhcpV6Enabled = defaultDhcpEnabled && wiredCfg.dhcp.v6;

      # Determine DHCP mode based on v4/v6 settings
      dhcpMode =
        if dhcpV4Enabled && dhcpV6Enabled then "yes"
        else if dhcpV4Enabled then "ipv4"
        else if dhcpV6Enabled then "ipv6"
        else "no";
    in {
      # Use systemd-networkd instead of the default NixOS network setup
      networking = {
        useNetworkd = mkDefault true;
        useDHCP = mkDefault false;      # Disable global DHCP since we manage it through systemd-networkd
        dhcpcd.enable = mkDefault false; # Explicitly disable dhcpcd since we're using networkd
      };

      systemd.network = {
        enable = true;

        # NETWORK DEVICE DEFINITIONS
        netdevs =
          # Bond definitions (prefix 10-)
          builtins.listToAttrs (map (bondCfg: {
            name = "10-${bondCfg.name}";
            value = {
              netdevConfig = {
                Kind = "bond";
                Name = bondCfg.name;
              } // optionalAttrs (bondCfg.mac != null) { MACAddress = bondCfg.mac; };

              bondConfig = {
                Mode = bondCfg.mode;
                MIIMonitorSec = toString (bondCfg.miimonFreq / 1000);
                UpDelaySec = toString (bondCfg.upDelay / 1000);
                DownDelaySec = toString (bondCfg.downDelay / 1000);
              } // optionalAttrs (bondCfg.primaryInterface != null) {
                PrimaryReselectPolicy = "always";
                PrimarySlave = bondCfg.primaryInterface;
              };
            };
          }) (attrValues bondCfgs))

          # Bridge definitions (prefix 20-)
          // builtins.listToAttrs (map (bridgeCfg: {
            name = "20-${bridgeCfg.name}";
            value = {
              netdevConfig = {
                Kind = "bridge";
                Name = bridgeCfg.name;
              } // optionalAttrs (bridgeCfg.mac != null) { MACAddress = bridgeCfg.mac; };
            };
          }) (attrValues bridgeCfgs));

        # NETWORK CONFIGURATIONS
        networks = let
          # Bond member interfaces
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

          # Standalone interfaces
          unbridgedNetworks = builtins.listToAttrs (map (ifData: {
            name = "10-${ifData.name}";
            value = recursiveUpdate
              (makeMacMatchConfig ifData.value.mac)
              (makeNetworkConfig ifData.value) // {
                linkConfig = { Name = ifData.name; };
              };
          }) unbridgedInterfaces);

          # Bond configurations
          unbridgedBondNetworks = builtins.listToAttrs (map (bondCfg: {
            name = "30-${bondCfg.name}";
            value = recursiveUpdate
              (makeNameMatchConfig bondCfg.name)
              (if elem bondCfg.name allBridgedBonds
               # Bridged bonds don't need IP config
               then { networkConfig.ConfigureWithoutCarrier = "yes"; }
               # Unbridged bonds need IP config
               else makeNetworkConfig bondCfg);
          }) (attrValues bondCfgs));

          # Bond-to-bridge connections
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

          # Interface-to-bridge connections
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

          # Bridge configurations
          bridgeNetworks = builtins.listToAttrs (map (bridgeCfg: {
            name = "50-${bridgeCfg.name}";
            value = recursiveUpdate
              (makeNameMatchConfig bridgeCfg.name)
              (makeNetworkConfig bridgeCfg);
          }) (attrValues bridgeCfgs));

          # Default DHCP configuration for unconfigured ethernet interfaces
          # Using 99- prefix to ensure it has lowest priority
          defaultDhcpNetwork = optionalAttrs defaultDhcpEnabled {
            "99-ethernet-default-dhcp" = {
              matchConfig = {
                Type = "ether";
                Kind = "!*"; # Match only physical interfaces (no virtual interfaces)
                # Ignore interfaces we've already configured specifically
                Name = "!veth* !docker* !podman*"; # Also ignore container interfaces
              };
              networkConfig = {
                DHCP = dhcpMode;
                IPv6AcceptRA = if dhcpV6Enabled || dhcpMode == "yes" then "yes" else "no";
                DHCPPrefixDelegation = dhcpV6Enabled || dhcpMode == "yes";
              };
            };
          };

        in unbridgedNetworks // bondedInterfaceNetworks //
           unbridgedBondNetworks // bondToBridgeNetworks //
           bridgedNetworks // bridgeNetworks //
           defaultDhcpNetwork;
      };

      assertions = [
        # Check for duplicate MAC addresses
        {
          assertion = !hasDuplicateMacs;
          message = "Error: Found duplicate MAC addresses in network configuration";
        }
      ]

      # Interface assertions
      ++ concatMap (pair: let name = pair.name; cfg = pair.value; in
        # MAC validation
        [{
          assertion = cfg.mac != null;
          message = "Interface ${name}: MAC address is required";
        }]
        # IPv4 validation
        ++ validateIPConfig "ipv4" "Interface ${name}" cfg
        # IPv6 validation
        ++ validateIPConfig "ipv6" "Interface ${name}" cfg
      ) (mapAttrsToList nameValuePair wiredCfg.interfaces)

      # Bridge assertions
      ++ concatMap (pair: let name = pair.name; bridgeCfg = pair.value; in
        let
          emptyInterfaces = bridgeCfg.interfaces == [] && bridgeCfg.bondInterfaces == [];
          invalidBonds = filter (bondName: !hasAttr bondName bondCfgs) bridgeCfg.bondInterfaces;
        in
        # Bridge structure validation
        [{
          assertion = !emptyInterfaces;
          message = "Bridge ${name}: Must have at least one interface or bond";
        }
        {
          assertion = invalidBonds == [];
          message = "Bridge ${name}: References non-existent bond(s): ${toString invalidBonds}";
        }]
        # IPv4 validation
        ++ validateIPConfig "ipv4" "Bridge ${name}" bridgeCfg
        # IPv6 validation
        ++ validateIPConfig "ipv6" "Bridge ${name}" bridgeCfg
      ) (mapAttrsToList nameValuePair bridgeCfgs)

      # Bond assertions
      ++ concatMap (pair: let name = pair.name; bondCfg = pair.value; in
        let
          isBridged = elem name allBridgedBonds;
          skipIPCheck = isBridged;
          emptyInterfaces = bondCfg.interfaces == [];
          isPrimaryMACValid = bondCfg.primaryInterface == null ||
                              elem bondCfg.primaryInterface bondCfg.interfaces;
        in
        # Bond structure validation
        [{
          assertion = !emptyInterfaces;
          message = "Bond ${name}: Must have at least one interface";
        }
        {
          assertion = isPrimaryMACValid;
          message = "Bond ${name}: Primary interface must be one of the interfaces in the bond";
        }]
        # IPv4 validation (only when not in a bridge)
        ++ (if skipIPCheck then [] else validateIPConfig "ipv4" "Bond ${name}" bondCfg)
        # IPv6 validation (only when not in a bridge)
        ++ (if skipIPCheck then [] else validateIPConfig "ipv6" "Bond ${name}" bondCfg)
      ) (mapAttrsToList nameValuePair bondCfgs);
    }
  );
}