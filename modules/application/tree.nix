{config, lib, pkgs, ...}:

let
  cfg = config.host.application.tree;
in
  with lib;
{
  options = {
    host.application.tree = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables file tree visualization tools";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      tree
    ];
  };
}