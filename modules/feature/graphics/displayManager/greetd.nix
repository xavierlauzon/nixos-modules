{ config, lib, pkgs, ... }:
with lib;

let
  greetdCfg = config.host.feature.graphics.displayManager.greetd;
  graphicsCfg = config.host.feature.graphics;

  dmDesktops = "${config.services.displayManager.sessionData.desktops}";
  waylandSessionDir = "${dmDesktops}/share/wayland-sessions";
  xSessionDir = "${dmDesktops}/share/xsessions";

  sessionDirs = lib.concatStringsSep ":" (
    [ waylandSessionDir ]
    ++ lib.optional config.services.xserver.enable xSessionDir
  );

  hyprlandUwsmEnabled =
    graphicsCfg.windowManager.manager == "hyprland"
    && config.programs.hyprland.withUWSM or false;
in

{
  options = {
    host.feature.graphics.displayManager.greetd = {
      greeter = {
        name = mkOption {
          type = types.enum ["gtk" "regreet" "tuigreet"];
          default = "tuigreet";
          description = "GreetD greeter to use";
        };
      };
      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Extra configuration that should be put in the greeter configuration file";
      };
    };
  };

  config = mkIf (config.host.feature.graphics.displayManager.manager == "greetd") {
    security.pam.services.greetd.enableGnomeKeyring = true;

    services = {
      displayManager = {
        sddm.enable = mkForce false;
        gdm.enable = mkForce false;
      };
      greetd = {
        enable = mkDefault true;
        useTextGreeter = mkDefault (greetdCfg.greeter.name == "tuigreet");
        settings = {
          default_session = {
            command = mkDefault (
              let
                greeter = greetdCfg.greeter.name;
                gtkgreetBin = "${pkgs.gtkgreet}/bin/gtkgreet";
                regreetBin = "${pkgs.regreet}/bin/regreet";
                tuigreetBin = "${pkgs.unstable.tuigreet}/bin/tuigreet";
                tuigreetCmd = if hyprlandUwsmEnabled
                  then "${tuigreetBin} --time --remember --remember-session --cmd '${lib.getExe config.programs.uwsm.package} start hyprland-uwsm.desktop'"
                  else "${tuigreetBin} --time --remember --remember-session --sessions ${sessionDirs}";
              in
                if greeter == "tuigreet" then tuigreetCmd
                else if greeter == "gtk" then "${gtkgreetBin} -l -s ${waylandSessionDir}"
                else if greeter == "regreet" then regreetBin
                else tuigreetCmd
            );
          };
        };
      };
      xserver.displayManager = {
        lightdm.enable = mkForce false;
        startx.enable = config.services.xserver.enable;
      };
    };
  };
}