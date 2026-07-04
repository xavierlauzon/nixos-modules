{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.host.feature.security.auditd;
in {
  options.host.feature.security.auditd = {
    enable = mkEnableOption "auditd monitoring";

    backlogLimit = mkOption {
      type = types.int;
      default = 8192;
      description = "The maximum number of outstanding audit buffers allowed";
    };

    failureMode = mkOption {
      type = types.enum [ "silent" "printk" "panic" ];
      default = "printk";
      description = "How to handle critical errors in the auditing system";
    };

    rateLimit = mkOption {
      type = types.int;
      default = 0;
      description = "The maximum messages per second permitted before triggering a failure";
    };
  };

  config = mkIf cfg.enable {
    security.audit = {
      enable = true;
      backlogLimit = cfg.backlogLimit;
      failureMode = cfg.failureMode;
      rateLimit = cfg.rateLimit;
    };
  };
}
