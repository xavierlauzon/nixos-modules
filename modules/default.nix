{ lib, ... }:

with lib;

{
  imports = [
    ./application
    ./container
    ./feature
    ./filesystem
    ./hardware
    ./network
    ./roles/default.nix
    ./service
  ];

  options.host = {
    configDir = mkOption {
      type = types.path;
      description = "Used to declare the nix store path for a config flake";
    };
  };
}