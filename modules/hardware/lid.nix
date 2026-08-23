{config, lib, pkgs, ...}:

let
  cfg = config.host.hardware.lid;
in
  with lib;
{
  options = {
    host.hardware.lid = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable Lid (typically in laptop)";
      };
    };
  };

  config = mkIf cfg.enable {
    boot = {
      kernelModules = [
        "acpi_call"
      ];
    };

    environment.systemPackages = with pkgs; [
      acpi
    ];

    services = {
      logind = {
        settings.Login = {
          HandleLidSwitchExternalPower = mkDefault "ignore";
          HandleLidSwitchDocked = mkDefault "ignore";
          HandleLidSwitch = mkDefault "suspend";
          HandlePowerKey = mkDefault "ignore";
        };
      };
    };
  };
}