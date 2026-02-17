{ config, lib, pkgs, ... }:
with lib;
let
  device = config.host.hardware ;
  backend = config.host.feature.graphics.backend;
  graphics = config.host.feature.graphics.enable;
  isHybridNvidia = (device.gpu == "hybrid-amd-nvidia");
in {
  config = mkIf (device.gpu == "amd" || device.gpu == "hybrid-amd" || device.gpu == "hybrid-amd-nvidia" || device.gpu == "integrated-amd")  {
    boot = lib.mkMerge [
      (lib.mkIf (lib.versionAtLeast pkgs.linux.version "6.2") {
        kernelModules = [
          "amdgpu"
        ];
      })
    ];

    hardware.graphics.extraPackages = with pkgs; [
      mesa
      rocmPackages.clr
      rocmPackages.clr.icd
      rocmPackages.rocminfo
      rocmPackages.rocm-smi
      rocmPackages.rocm-runtime
    ];

    hardware.enableRedistributableFirmware = true;

    hardware.amdgpu = {
        initrd.enable = true;
        opencl.enable = true;
    };

    # When paired with NVIDIA dGPU, let nvidia.nix handle LIBVA and videoDrivers
    environment = mkIf (!isHybridNvidia) {
      sessionVariables = mkIf (graphics) {
        LIBVA_DRIVER_NAME = "radeonsi";
      };
    };

    services.xserver.videoDrivers = mkIf ((!isHybridNvidia) && (graphics) && (backend == "x")) [
      "amdgpu"
    ];
  };
}