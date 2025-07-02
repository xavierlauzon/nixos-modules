{config, lib, pkgs, ...}:

let
  cfg = config.host.application.openssl;
in
  with lib;
{
  options = {
    host.application.openssl = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables OpenSSL";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      openssl
    ];
  };
}