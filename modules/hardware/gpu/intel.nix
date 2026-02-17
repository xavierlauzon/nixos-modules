{ config, lib, pkgs, ... }:
with lib;
let
  device = config.host.hardware ;
in {
  config = mkIf (device.gpu == "intel" || device.gpu == "hybrid-nvidia" )  {

    boot.initrd.kernelModules = ["i915"];
    services.xserver.videoDrivers = ["modesetting"];

    hardware.graphics = {
      extraPackages = with pkgs; [
        intel-media-driver          # iHD VA-API driver (Broadwell+, recommended)
        intel-compute-runtime       # OpenCL (Gen 12+; use intel-compute-runtime-legacy1 for Gen 8-11)
        libvdpau-va-gl
        vaapiVdpau
      ];
    };

    environment.variables = mkIf (config.hardware.graphics.enable && device.gpu != "hybrid-nvidia") {
      VDPAU_DRIVER = "va_gl";
    };
  };
}