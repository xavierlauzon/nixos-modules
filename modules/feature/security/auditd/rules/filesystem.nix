{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.host.feature.security.auditd.rules.filesystem;
in {
  options.host.feature.security.auditd.rules.filesystem = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable filesystem monitoring rules";
    };
  };

  config.security.audit.rules = mkIf cfg.enable [
    # =============================================================================
    # Critical File System Monitoring
    # =============================================================================

    # /etc directory - system configuration files
    "-w /etc/ -p wa -k etc_changes"
    "-w /etc/passwd -p wa -k passwd_file"
    "-w /etc/shadow -p wa -k shadow_file"
    "-w /etc/group -p wa -k group_file"
    "-w /etc/gshadow -p wa -k gshadow_file"
    "-w /etc/sudoers -p wa -k sudoers_file"

    # Critical system binaries
    "-w /usr/bin/ -p x -k usr_bin_exec"
    "-w /bin/ -p x -k bin_exec"
    "-w /sbin/ -p x -k sbin_exec"
    "-w /lib/ -p x -k lib_exec"
    "-w /lib64/ -p x -k lib64_exec"

    # Kernel modules and firmware
    "-w /lib/modules/ -p wa -k kernel_modules"
    "-w /boot/ -p wa -k boot_changes"

    # Systemd unit files
    "-w /etc/systemd/ -p wa -k systemd_config"
    "-w /usr/lib/systemd/ -p wa -k systemd_units"

    # =============================================================================
    # File Permission and Attribute Changes
    # =============================================================================

    # Watch for permission changes on critical directories
    "-a exit,always -F arch=b64 -S chmod -S fchmodat -S chown -S fchownat -S renameat -k perm_changes"
    "-a exit,always -F arch=b32 -S chmod -S fchmodat -S chown -S fchownat -S renameat -k perm_changes"

    # Watch for attribute changes (immutable flag, etc.)
    "-a exit,always -F arch=b64 -S chattr -S ioctl -S mount -S umount2 -k attr_changes"

    # =============================================================================
    # Mount and Filesystem Events
    # =============================================================================

    # Monitor mount operations
    "-a exit,always -F arch=b64 -S mount -S umount -S umount2 -S pivot_root -k mount_events"
    "-a exit,always -F arch=b32 -S mount -S umount -S umount2 -k mount_events"

    # Watch for NFS and CIFS mounts (network filesystems)
    "-w /etc/fstab -p wa -k fstab_changes"
    "-w /etc/mtab -p wa -k mtab_changes"

    # =============================================================================
    # Temporary and Sticky Directories
    # =============================================================================

    # Monitor /tmp, /var/tmp for suspicious activity
    "-a exit,always -F arch=b64 -S open -S openat -F dir=/tmp -p wa -k tmp_access"
    "-a exit,always -F arch=b32 -S open -S openat -F dir=/tmp -p wa -k tmp_access"

    # =============================================================================
    # Log Files (read access for audit trail)
    # =============================================================================

    # Monitor log file modifications
    "-w /var/log/audit/ -p rwxa -k audit_logs"
    "-w /var/log/auth.log -p rwa -k auth_log"
    "-w /var/log/syslog -p rwa -k syslog"
  ];
}
