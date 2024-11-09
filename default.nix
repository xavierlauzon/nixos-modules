{ lib, configDir, ... }:

with lib;
let
  importWithArgs = path: import path { inherit lib configDir; };
in
{
  options.nixos-modules.configDir = mkOption {
    type = types.str;
    default = configDir;
    description = "Path to the system's current flake";
  };

  imports = [
    (importWithArgs ./application/default.nix)
    (importWithArgs ./container/default.nix)
    (importWithArgs ./darwin/default.nix)
    (importWithArgs ./feature/default.nix)
    (importWithArgs ./filesystem/default.nix)
    (importWithArgs ./hardware/default.nix)
    (importWithArgs ./network/default.nix)
    (importWithArgs ./roles/default.nix)
    (importWithArgs ./service/default.nix)
  ];
}
