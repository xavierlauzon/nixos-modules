{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.host.feature.security.auditd.rules.network;
in {
  options.host.feature.security.auditd.rules.network = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable network monitoring rules";
    };
  };

  config.security.audit.rules = mkIf cfg.enable [
    # =============================================================================
    # Network Configuration Changes
    # =============================================================================

    # Firewall configuration changes (iptables/nftables)
    "-a exit,always -F arch=b64 -S setsockopt -S getsockopt -k network_config"
    "-w /etc/iptables/ -p wa -k iptables_config"
    "-w /etc/nftables.conf -p wa -k nftables_config"

    # Network interface configuration (ioctl for ifconfig/ip commands)
    "-a exit,always -F arch=b64 -S ioctl -k network_interface"
    "-w /etc/network/ -p wa -k network_config"
    "-w /etc/netplan/ -p wa -k netplan_config"

    # DNS configuration changes
    "-w /etc/resolv.conf -p wa -k dns_changes"
    "-w /etc/nsswitch.conf -p wa -k nsswitch_changes"

    # =============================================================================
    # Routing Table Changes (via ioctl)
    # =============================================================================

    # Monitor routing table modifications
    "-a exit,always -F arch=b64 -S ioctl -F a2=0x8931 -k routing_add"      # SIOCDROUTE
    "-a exit,always -F arch=b64 -S ioctl -F a2=0x8933 -k routing_del"      # SIOCDELRT

    # =============================================================================
    # Socket and Connection Events
    # =============================================================================

    # Network socket creation with filtering for specific protocols
    "-a exit,always -F arch=b64 -S socket -F sockfamily=2 -S connect -S accept -k ipv4_network"
    "-a exit,always -F arch=b64 -S socket -F sockfamily=10 -S connect -S accept -k ipv6_network"

    # =============================================================================
    # Network Service Configuration
    # =============================================================================

    # Watch for changes to network service configurations
    "-w /etc/systemd/network/ -p wa -k systemd_network"

    # =============================================================================
    # Cilium-specific Network Monitoring (eBPF)
    # =============================================================================

    # Monitor eBPF-related files and directories
    "-w /sys/fs/bpf/ -p rwa -k bpf_maps"
    "-a exit,always -F arch=b64 -S bpf -k bpf_calls"

    # Cilium network policy changes (if using cilium)
    "-w /var/lib/cilium/ -p wa -k cilium_data"
  ];
}
