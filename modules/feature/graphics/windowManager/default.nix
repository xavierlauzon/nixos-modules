{config, lib, pkgs, ...}:
let
  cfg = config.host.feature.graphics.windowManager;
in
  with lib;
{
  imports = [
    ./hyprland.nix
  ];

  options = {
    host.feature.graphics.windowManager = {
      manager = mkOption {
        type = types.enum [ "hyprland" null];
        default = null;
        description = "Window Manager to use";
      };
    };
  };
}
