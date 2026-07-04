{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.host.feature.security.auditd.rules.base;
in {
  options.host.feature.security.auditd.rules.base = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable base system call monitoring rules";
    };
  };

  config.security.audit.rules = mkIf cfg.enable [
    # =============================================================================
    # Base System Call Monitoring
    # =============================================================================

    # Monitor all execve calls (process execution) - arch-specific
    "-a exit,always -F arch=b64 -S execve"
    "-a exit,always -F arch=b32 -S execve"

    # File system operations for monitoring file creation/deletion/modification
    "-a exit,always -F arch=b64 -S open -S openat -S creat -S unlink -S link -S rename"
    "-a exit,always -F arch=b32 -S open -S openat -S creat -S unlink -S link -S rename"

    # File permission and ownership changes
    "-a exit,always -F arch=b64 -S chmod -S fchmod -S chown -S fchown -S lchown -S setxattr -S fsetxattr -S getxattr -S listxattr -S removexattr"
    "-a exit,always -F arch=b32 -S chmod -S fchmod -S chown -S fchown -S lchown -S setxattr -S fsetxattr -S getxattr -S listxattr -S removexattr"

    # Network-related system calls
    "-a exit,always -F arch=b64 -S socket -S connect -S bind -S accept -S listen -S sendto -S recvfrom -S sendmsg -S recvmsg"
    "-a exit,always -F arch=b32 -S socket -S connect -S bind -S accept -S listen -S sendto -S recvfrom -S sendmsg -S recvmsg"

    # Process management and privilege escalation
    "-a exit,always -F arch=b64 -S setuid -S setgid -S setreuid -S setregid -S setresuid -S setresgid -S seteuid -S setegid"
    "-a exit,always -F arch=b32 -S setuid -S setgid -S setreuid -S setregid -S setresuid -S setresgid -S seteuid -S setegid"

    # System time changes (important for log integrity)
    "-a exit,always -F arch=b64 -S settimeofday -S clock_settime"
    "-a exit,always -F arch=b32 -S settimeofday -S stime"

    # Module loading/unloading (kernel module manipulation)
    "-a exit,always -F arch=b64 -S init_module -S delete_module -S finit_module"

    # Kernel debugging interfaces
    "-a exit,always -F arch=b64 -S kexec_load -S kexec_file_load"
  ];
}
