{config, lib, pkgs, ...}:

let
  cfg = config.host.feature.powermanagement.thermal;
  isIntel = (config.host.hardware.cpu == "intel");
  isAmd = (config.host.hardware.cpu == "amd");
in
  with lib;
{
  options = {
    host.feature.powermanagement.thermal = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables thermal management";
      };
      thermald = mkOption {
        default = isIntel;
        type = with types; bool;
        description = "Enables thermal management for Intel Architecture";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      lm_sensors
    ];

    services = {
      thermald.enable = cfg.thermald;
    };
  };
}