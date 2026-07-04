{ config, lib, pkgs, ... }:
with lib;
let
  sys = config.host.hardware;
  cfg = config.host.feature.security;
in {
  options = {
    host.feature.security = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables security hardening features";
      };
    };
  };

  config = mkIf cfg.enable {
    boot = {
      blacklistedKernelModules = [
        # Obscure network protocols
        "ax25"
        "netrom"
        "rose"
        # Old or rare filesystems insufficiently audited
        "adfs"
        "affs"
        "bfs"
        "befs"
        "cramfs"
        "efs"
        "erofs"
        "exofs"
        "freevxfs"
        "f2fs"
        "hfs"
        "hpfs"
        "jfs"
        "minix"
        "nilfs2"
        "ntfs"
        "omfs"
        "qnx4"
        "qnx6"
        "sysv"
        "ufs"
      ] ++ lib.optionals (!sys.bluetooth.enable) [
        "btusb"                                         # Allow Bluetooth dongles to work
      ] ++ lib.optionals (!sys.webcam.enable) [
        "uvcvideo"                                      # Allow webcam to work
      ];

      kernel.sysctl = {
        "kernel.ftrace_enabled" = mkDefault false;       # Disable ftrace debugging
        "kernel.kptr_restrict" = mkOverride 500 2;       # Hide kptrs even for processes with CAP_SYSLOG
        "kernel.sysrq" = mkDefault 0;                    # Disable Magic SysRq key (security concern)
        "kernel.yama.ptrace_scope" = mkDefault 2;        # Restrict ptrace() usage to related processes

        "net.core.bpf_jit_enable" = mkDefault false;     # Override when using CNI like Cilium (K8s)
        "net.core.bpf_jit_harden" = mkDefault 2;         # May cause slight performance degredation
      };
    };

    security = {
      allowSimultaneousMultithreading = mkDefault false;
      allowUserNamespaces = mkDefault true;              # User namespaces required for sandboxing/Docker
      apparmor = {
        enable = mkDefault true;
        killUnconfinedConfinables = mkDefault true;
        packages = [ pkgs.apparmor-profiles ];
      };
      forcePageTableIsolation = mkDefault true;          # PTI mitigates Meltdown vulnerability
      lockKernelModules = mkDefault false;               # Breaks virtd, wireguard and iptables
      pam = {
        loginLimits = [                                  # Fix "too many files open" for wheel group
          {
            domain = "@wheel";
            item = "nofile";
            type = "soft";
            value = "524288";
          }
          {
            domain = "@wheel";
            item = "nofile";
            type = "hard";
            value = "1048576";
          }
        ];
      };
      polkit.extraConfig = ''                           # Log polkit request actions
        polkit.addRule(function(action, subject) {
          polkit.log("user " +  subject.user + " is attempting action " + action.id + " from PID " + subject.pid);
        });
      '';
      protectKernelImage = mkDefault true;               # Protect kernel image from modification
      sudo = {
        enable = mkDefault true;
        execWheelOnly = mkDefault true;
        extraConfig = ''
          Defaults env_keep += "EDITOR PATH"
          Defaults lecture = never                      # Rollback results in sudo lectures after each reboot
          Defaults passprompt="[31m sudo: password for %p@%h, running as %U:[0m "
          Defaults pwfeedback
          Defaults timestamp_timeout = 300
        '';
        wheelNeedsPassword = mkDefault false;
      };
      unprivilegedUsernsClone = config.host.feature.virtualization.docker.enable; # Disable unless containers enabled
      virtualisation = {
        flushL1DataCache = "always";                     # Spectre mitigation - flush L1 cache before guests
      };
    };
  };
}
