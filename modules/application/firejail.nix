{config, lib, pkgs, ...}:

let
  cfg = config.host.application.firejail;
in
  with lib;
{
  options = {
    host.application.firejail = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Linux namespaces and seccomp-bpf sandbox ";
      };
    };
  };

  config = mkIf cfg.enable {
    programs.firejail = {
      enable = true;
    };
  };
}