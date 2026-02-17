{config, lib, pkgs, ...}:
  with lib;
{
  imports = [
    ./amd.nix
    ./intel.nix
    ./nvidia.nix
  ];

  options = {
    host.hardware.gpu = mkOption {
        type = types.enum [ "amd" "intel" "nvidia" "hybrid-nvidia" "hybrid-amd" "hybrid-amd-nvidia" "integrated-amd" "pi" null];
        default = null;
        description = "Manufacturer/type of the primary system GPU";
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