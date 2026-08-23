{ config, lib, pkgs, ... }:
with lib;
let
  device = config.host.hardware;
  graphics = config.host.feature.graphics.enable;
  isHybridNvidia = (device.gpu.type == "hybrid-amd-nvidia");
  renderNvidia = device.render == "nvidia";
in {
  config = mkIf (device.gpu.type == "amd" || device.gpu.type == "hybrid-amd" || device.gpu.type == "hybrid-amd-nvidia" || device.gpu.type == "integrated-amd") {
    boot = lib.mkMerge [
      (lib.mkIf (lib.versionAtLeast pkgs.linux.version "6.2") {
        kernelModules = [
          "amdgpu"
        ];
      })
    ];

    hardware.graphics.extraPackages = with pkgs; [
      amdgpu_top
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

    # When paired with NVIDIA dGPU, LIBVA handling depends on render mode:
    # - render = "amd": iGPU handles video decode (radeonsi)
    # - render = "nvidia": nvidia.nix handles LIBVA (nvidia driver)
    # - non-hybrid: iGPU handles everything (radeonsi)
    environment = mkIf (!isHybridNvidia || !renderNvidia) {
      sessionVariables = mkIf graphics {
        LIBVA_DRIVER_NAME = mkIf isHybridNvidia "radeonsi" "radeonsi";
      };
    };
  };
}
