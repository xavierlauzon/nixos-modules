# GPU Modules

GPU hardware configuration for AMD, NVIDIA, and dual GPU setups.

## Options

### `host.hardware.gpu.type`

| Value | Description |
|---|---|
| `"amd"` | AMD GPU only (discrete or integrated) |
| `"intel"` | Intel iGPU only |
| `"nvidia"` | NVIDIA GPU only (discrete, no iGPU) |
| `"hybrid-amd-nvidia"` | AMD iGPU + NVIDIA dGPU |
| `"hybrid-nvidia"` | Intel iGPU + NVIDIA dGPU |
| `"hybrid-amd"` | AMD discrete + AMD integrated |
| `"integrated-amd"` | AMD APU/iGPU only |
| `null` | No GPU configuration applied |

### `host.hardware.gpu.render`

Controls which GPU handles rendering in hybrid mode. Only applicable when `gpu` is set to a hybrid type.

| Value | Behavior | Default |
|---|---|---|
| `"amd"` | iGPU handles default rendering and display. Use `nvidia-offload` to run specific apps on the NVIDIA dGPU. Best for battery life and general desktop use. | **Default** |
| `"nvidia"` | All rendering is offloaded to the NVIDIA dGPU globally. Best for gaming where you want maximum performance without per-app overrides. | |

### `host.hardware.prime.mode`

PRIME configuration mode for hybrid GPU setups.

| Value | Description |
|---|---|
| `"offload"` | Enable PRIME render offload. |


### `host.hardware.prime.<busId>`

PCI bus ID for each GPU. **Required for hybrid setups**

| Option | Description |
|---|---|
| `host.hardware.prime.amdgpuBusId` | Bus ID of the AMD iGPU |
| `host.hardware.prime.intelBusId` | Bus ID of the Intel iGPU |
| `host.hardware.prime.nvidiaBusId` | Bus ID of the NVIDIA dGPU |

**Finding bus IDs:**

```bash
nix shell nixpkgs#pciutils -c lspci -D -d ::03xx
```

Example output:
```
0000:04:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Phoenix1 [Radeon Graphics]
0000:c1:00.0 VGA compatible controller: NVIDIA Corporation AD107M [GeForce RTX 4070 Mobile]
```

Convert hex to decimal and format as `PCI:<bus>@<domain>:<device>:<func>`:
- `04:00.0` → `PCI:4@0:0:0`
- `c1:00.0` → `PCI:193@0:0:0`

Configuration:
```nix
host.hardware.prime = {
  amdgpuBusId = "PCI:4@0:0:0";
  nvidiaBusId = "PCI:193@0:0:0";
};
```
