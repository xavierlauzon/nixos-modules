{config, inputs, lib, pkgs, ...}:

let
  cfg = config.host.feature.gaming.heroic;
in
  with lib;
  with pkgs;
{
  options = {
    host.feature.gaming.heroic = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables heroic gaming support";
      };
    };
  };

  config = lib.mkIf (cfg.enable) {
    environment.systemPackages = [
      heroic
      ];
  };
}