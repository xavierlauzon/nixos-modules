{ config, inputs, lib, pkgs, specialArgs, ... }:
with lib;
let
  graphics = config.host.feature.graphics;
in {
  config = mkIf (graphics.enable && graphics.backend == "wayland") {
    environment.pathsToLink = [ "/libexec" ];

    programs = {
      dconf.enable = mkDefault true;
      seahorse.enable = mkDefault true;
    };

    security = {
      pam = {
        services.gdm.enableGnomeKeyring = mkDefault true;
        services.swaylock.text = mkDefault ''
         # PAM configuration file for the swaylock screen locker. By default, it includes
         # the 'login' configuration file (see /etc/pam.d/login)
         auth include login
       '';
      };
      polkit = {
        enable = mkDefault true;
      };
    };

    services = {
      gvfs = {
        enable = mkDefault true;
      };

      gnome.gnome-keyring = {
        enable = mkDefault true;
      };

      libinput.enable = mkDefault true;

      xserver = {
        enable = mkDefault false;
        desktopManager = {
          xterm.enable = false;
        };
        xkb.layout = mkDefault "us";
      };
    };
  };
}