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
  backend = config.host.feature.graphics.backend;
  isHybrid = (device.gpu == "hybrid-nvidia" || device.gpu == "hybrid-amd-nvidia");
in {
  config = mkIf (device.gpu == "nvidia" || isHybrid)  {
    nixpkgs.config.allowUnfree = true;

    services.xserver = mkMerge [
      {
        videoDrivers = [ "nvidia" ];
      }

      (mkIf ( backend == "x") {
        # disable DPMS
        monitorSection = ''
          Option "DPMS" "false"
        '';

        # disable screen blanking in general
        serverFlagsSection = ''
          Option "StandbyTime" "0"
          Option "SuspendTime" "0"
          Option "OffTime" "0"
          Option "BlankTime" "0"
        '';
      })
    ];

boot = {
      blacklistedKernelModules = [
        "nouveau"
      ];
    };

    environment = {
      sessionVariables = mkMerge [
        (mkIf (config.host.feature.graphics.enable) {
          LIBVA_DRIVER_NAME = "nvidia";
        })

        (mkIf ((backend == "wayland") && isHybrid && (config.host.feature.graphics.enable)) {
          __NV_PRIME_RENDER_OFFLOAD = "1";
          WLR_DRM_DEVICES = mkDefault "/dev/dri/card1:/dev/dri/card0";
        })
      ];
      systemPackages = with pkgs; mkIf (config.host.feature.graphics.enable) [
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
        prime = {
          offload.enableOffloadCmd = isHybrid;
          amdgpuBusId = mkIf (prime.amdgpuBusId != "") prime.amdgpuBusId;
          intelBusId = mkIf (prime.intelBusId != "") prime.intelBusId;
          nvidiaBusId = mkIf (prime.nvidiaBusId != "") prime.nvidiaBusId;
        };
        powerManagement = {
          enable = mkDefault true;
          finegrained = isHybrid;
        };

        open = mkDefault false;
        nvidiaSettings = false;
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