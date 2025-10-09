{ config, lib, pkgs, ... }:
with lib;
let
  device = config.host.hardware ;
  backend = config.host.feature.graphics.backend;
  graphics = config.host.feature.graphics.enable;
in {
  config = mkIf (device.gpu == "amd" || device.gpu == "hybrid-amd" || device.gpu == "integrated-amd")  {
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
      rocmPackages.rocm-runtime
    ];

    hardware.enableRedistributableFirmware = true;

    hardware.amdgpu = {
        initrd.enable = true;
        opencl.enable = true;
    };

    environment = {
      sessionVariables = mkMerge [
        (mkIf (graphics) {
          LIBVA_DRIVER_NAME = "radeonsi";
        })

        (mkIf ((graphics) && (backend == "wayland")) {
          WLR_NO_HARDWARE_CURSORS = "1";
        })
      ];
    };

    services.xserver.videoDrivers = (mkIf ((graphics) && (backend == "x"))) [
      "amdgpu"
    ];
  };
}