{ config, lib, ... }:
with lib;
let
  kver = config.boot.kernelPackages.kernel.version;
  device = config.host.hardware ;
in {
  config = mkIf (device.cpu == "amd" || device.cpu == "vm-amd") {
    hardware.cpu.amd.updateMicrocode = true;

    host.feature.boot.kernel = {
      modules = [
        "kvm-amd"
      ];
      parameters = [
        "amd_pstate=active"
      ];
    };
  nixpkgs.hostPlatform = "x86_64-linux";
  };
}