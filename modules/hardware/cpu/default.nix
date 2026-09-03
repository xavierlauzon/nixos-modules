{config, lib, pkgs, ...}:
with lib;
{
  imports = [
    ./amd.nix
    ./arm.nix
    ./intel.nix
  ];

  options = {
    host.hardware = {
      cpu = mkOption {
        type = types.enum ["amd" "arm" "intel" "vm-amd" "vm-intel" null];
        default = null;
        description = "Type of CPU";
      };
    };
  };
}