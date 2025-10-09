{config, lib, pkgs, inputs, ...}:

let
  cfg = config.host.feature.boot.graphical;
in
  with lib;
{
  options = {
    host.feature.boot.graphical = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables graphical boot screen";
      };
    };
  };

  config = mkIf cfg.enable {
    boot = {
      plymouth = {
        enable = true ;
        theme = "minecraft" ;
        themePackages = [ inputs.minecraft-plymouth-theme.packages.${pkgs.system}.plymouth-minecraft-theme ];
      };
    };
  };
}
