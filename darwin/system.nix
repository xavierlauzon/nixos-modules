{config, lib, pkgs, ...}:

let
  cfg = config.host.darwin.system;
in
  with lib;
{
  options = {
    host.darwin.system = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Configure basic darwin system settings";
      };
    };
  };

  config.system = mkIf cfg.enable {

    activationScripts.postUserActivation.text = ''
      # activateSettings -u will reload the settings from the database and apply them to the current session,
      # so we do not need to logout and login again to make the changes take effect.
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

  };
}