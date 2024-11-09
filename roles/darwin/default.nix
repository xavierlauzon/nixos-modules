{ config, lib, modulesPath, pkgs, ... }:
let
  role = config.host.role;
in
  with lib;
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  config = mkIf (role == "darwin") {
    host = {
      feature = {
        development = {
          crosscompilation = {
            enable = mkDefault true;
            platform = "aarch64-linux";
          };
        };
        fonts = {
          enable = mkDefault true;
        };
        virtualization = {
          docker = {
            enable = mkDefault true;
          };
        };
      };
      darwin = {
        system.enable = true;
      };
    };
 };
}