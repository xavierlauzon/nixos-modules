{config, lib, pkgs, ...}:
  with lib;
let
  gpu = config.host.hardware.gpu.type;
  isHybrid = (gpu == "hybrid-nvidia" || gpu == "hybrid-amd" || gpu == "hybrid-amd-nvidia");
in
{
  imports = [
    ./amd.nix
    ./intel.nix
    ./nvidia.nix
  ];

  options = {
    host.hardware.gpu.type = mkOption {
      type = types.enum [ "amd" "intel" "nvidia" "hybrid-nvidia" "hybrid-amd" "hybrid-amd-nvidia" "integrated-amd" null ];
      default = null;
      description = "Manufacturer/type of the primary system GPU";
    };

    host.hardware.gpu.render = mkOption {
      type = types.enum [ "amd" "nvidia" null ];
      default = if isHybrid then "amd" else null;
      description = ''
        Which GPU handles rendering in hybrid mode.
        - "amd": iGPU handles default rendering; use nvidia-offload for dGPU games/apps.
        - "nvidia": all rendering on NVIDIA dGPU; iGPU only handles display scanout.
        Only applicable when gpu is set to a hybrid type.
      '';
    };

    host.hardware.prime.mode = mkOption {
      type = types.enum [ "offload" null ];
      default = if isHybrid then "offload" else null;
      description = ''
        PRIME mode for hybrid GPU setups.
        - "offload": iGPU displays, dGPU renders on demand via nvidia-offload.
          Works on Wayland. Default for hybrid setups.
        Note: PRIME sync is X11-only and not supported.
      '';
    };

    host.hardware.prime = {
      amdgpuBusId = mkOption {
        type = types.str;
        default = "";
        description = "PCI Bus ID of the AMD integrated GPU (e.g. 'PCI:6:0:0')";
      };
      intelBusId = mkOption {
        type = types.str;
        default = "";
        description = "PCI Bus ID of the Intel integrated GPU (e.g. 'PCI:0:2:0')";
      };
      nvidiaBusId = mkOption {
        type = types.str;
        default = "";
        description = "PCI Bus ID of the NVIDIA discrete GPU (e.g. 'PCI:1:0:0')";
      };
    };
  };
}
