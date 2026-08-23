{ config, lib, pkgs, ... }:
with lib;
let
  nvStable = config.boot.kernelPackages.nvidiaPackages.stable.version;
  nvBeta = config.boot.kernelPackages.nvidiaPackages.beta.version;

  nvidiaPackage =
    if (versionOlder nvBeta nvStable)
    then config.boot.kernelPackages.nvidiaPackages.stable
    else config.boot.kernelPackages.nvidiaPackages.beta;

  device = config.host.hardware;
  prime = config.host.hardware.prime;
  graphics = config.host.feature.graphics.enable;
  isHybrid = (device.gpu.type == "hybrid-nvidia" || device.gpu.type == "hybrid-amd-nvidia");
  isHybridAmd = (device.gpu.type == "hybrid-amd-nvidia");
  isHybridIntel = (device.gpu.type == "hybrid-nvidia");
  renderNvidia = device.render == "nvidia";
  primeOffload = prime.mode == "offload";
in {
  config = mkIf (device.gpu.type == "nvidia" || isHybrid) {
    nixpkgs.config.allowUnfree = true;

    assertions = mkIf isHybrid [
      {
        assertion = (primeOffload -> (prime.amdgpuBusId != "" || prime.intelBusId != "") && prime.nvidiaBusId != "");
        message = "Prime offload requires both iGPU and NVIDIA dGPU bus IDs to be set (host.hardware.prime.amdgpuBusId/intelBusId and host.hardware.prime.nvidiaBusId).";
      }
    ];

    services.xserver.videoDrivers = mkMerge [
      [ "nvidia" ]
      (mkIf (isHybrid && primeOffload) [ "modesetting" ])
    ];

    boot = {
      blacklistedKernelModules = [
        "nouveau"
      ];
    };

    environment = {
      sessionVariables = mkMerge [
        (mkIf graphics {
          LIBVA_DRIVER_NAME = mkIf renderNvidia "nvidia" (mkIf isHybridAmd "radeonsi" "iHD");
        })

        (mkIf (renderNvidia && graphics) {
          __NV_PRIME_RENDER_OFFLOAD = "1";
          __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          __VK_LAYER_NV_optimus = "NVIDIA_only";
        })
      ];

      systemPackages = with pkgs; mkIf graphics [
        libva
        libva-utils
        vulkan-loader
        vulkan-tools
        vulkan-validation-layers
      ];
    };

    hardware = {
      nvidia = {
        package = mkDefault nvidiaPackage;
        modesetting.enable = mkDefault true;
        open = mkDefault true;

        prime = {
          offload = {
            enable = mkIf isHybrid (mkDefault primeOffload);
            enableOffloadCmd = mkIf isHybrid true;
          };
          amdgpuBusId = mkIf (prime.amdgpuBusId != "") prime.amdgpuBusId;
          intelBusId = mkIf (prime.intelBusId != "") prime.intelBusId;
          nvidiaBusId = mkIf (prime.nvidiaBusId != "") prime.nvidiaBusId;
        };

        powerManagement = {
          enable = mkDefault true;
          finegrained = mkIf isHybrid (mkDefault true);
        };

        dynamicBoost = mkIf isHybrid {
          enable = mkDefault true;
        };

        nvidiaSettings = mkDefault true;
        nvidiaPersistenced = true;
        forceFullCompositionPipeline = mkDefault false;
      };

      graphics = {
        extraPackages = with pkgs; [
          nvidia-vaapi-driver
        ];
      };
    };
  };
}
