{ config, inputs, lib, pkgs, ... }:
with lib;
let
  graphics = config.host.feature.graphics;
in

{
  config = mkIf (graphics.enable && graphics.windowManager.manager == "hyprland") {
    programs = {
      hyprland = {
        enable = mkDefault true;
        package = pkgs.hyprland;
        portalPackage = pkgs.xdg-desktop-portal-hyprland;
#        package = inputs.hyprland.packages.${pkgs.system}.hyprland;
#        portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
      };
    };

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      config.common = {
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
        "org.freedesktop.portal.FileChooser" = [ "xdg-desktop-portal-shana" ];
      };
      extraPortals = with pkgs; [
#        inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
        xdg-desktop-portal-wlr
        xdg-desktop-portal-shana
      ];
    };
  };
}
