{config, lib, pkgs, ...}:

let
  cfg = config.host.hardware.alienware;
in
  with lib;
{
  options = {
    host.hardware.alienware = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable Alienware/Dell laptop hardware support";
      };
      fanControl = {
        enable = mkOption {
          default = true;
          type = with types; bool;
          description = "Enable Dell fan monitoring and control support via i8k/dell-smm-hwmon";
        };
      };
      keyboard = {
        enable = mkOption {
          default = true;
          type = with types; bool;
          description = "Enable AlienFX keyboard RGB backlight support";
        };
      };
      thermalProfile = {
        enable = mkOption {
          default = true;
          type = with types; bool;
          description = "Enable Dell/Alienware platform thermal profile support via WMI";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    boot = {
      kernelModules = [
        "dell-wmi"
        "dell-laptop"
        "dell-smm-hwmon"
        "alienware-wmi"
      ];

      kernelParams = mkIf cfg.fanControl.enable [
        "dell_smm_hwmon.ignore_dmi=1"      # Needed for newer Alienware models
      ];
    };

    environment.systemPackages = with pkgs; [
      lm_sensors
    ] ++ optionals cfg.fanControl.enable [
      i2c-tools
    ] ++ optionals cfg.keyboard.enable [
      openrgb
    ];

    hardware.i2c.enable = mkIf cfg.fanControl.enable true;

    services.hardware.openrgb = mkIf cfg.keyboard.enable {
      enable = mkDefault true;
    };
  };
}
