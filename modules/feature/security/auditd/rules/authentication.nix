{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.host.feature.security.auditd.rules.authentication;
in {
  options.host.feature.security.auditd.rules.authentication = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable authentication event monitoring rules";
    };
  };

  config.security.audit.rules = mkIf cfg.enable [
    # =============================================================================
    # Authentication Events
    # =============================================================================

    # SSH authentication events (successful and failed)
    "-w /etc/ssh/sshd_config -p rwxa -k ssh_config"

    # Sudo usage tracking
    "-w /usr/bin/sudo -p x -k sudo_exec"
    "-a exit,always -F arch=b64 -S execve -F exe=/usr/bin/sudo -k sudo_exec"

    # User account management (useradd, usermod, userdel)
    "-w /usr/sbin/useradd -p x -k user_mgmt"
    "-w /usr/sbin/usermod -p x -k user_mgmt"
    "-w /usr/sbin/userdel -p x -k user_mgmt"

    # Group management (groupadd, groupmod, groupdel)
    "-w /usr/sbin/groupadd -p x -k group_mgmt"
    "-w /usr/sbin/groupmod -p x -k group_mgmt"
    "-w /usr/sbin/groupdel -p x -k group_mgmt"

    # Password file changes
    "-w /etc/passwd -p wa -k passwd_changes"
    "-w /etc/shadow -p wa -k shadow_changes"
    "-w /etc/gshadow -p wa -k gshadow_changes"
    "-w /etc/group -p wa -k group_changes"

    # SSH key management (root only, home directories vary by user)
    "-w /root/.ssh/authorized_keys -p wa -k root_ssh_authorized_keys"

    # Security context changes (SELinux/AppArmor)
    "-w /etc/selinux/config -p wa -k selinux_config"
    "-a exit,always -F arch=b64 -S setfscreatecon -S setexeccon -S setfilecon -k security_context"

    # =============================================================================
    # Additional Authentication Monitoring
    # =============================================================================

    # Watch for changes to sudoers file
    "-w /etc/sudoers -p wa -k sudoers_changes"
    "-w /etc/sudoers.d/ -p wa -k sudoers_d_changes"

    # Monitor PAM configuration files
    "-w /etc/pam.d/ -p wa -k pam_config"
  ];
}
