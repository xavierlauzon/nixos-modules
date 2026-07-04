# Netbird VPN Client Module

Client-only module for connecting to Netbird networks. Each tunnel is an independent
client daemon that can point to a different management server.

Management plane components are out of scope.

## Basic usage

```nix
host.network.vpn.netbird = {
  enable = true;
  managementUrl = "https://netbird.example.com:443";
  tunnels = {
    lab = {};
    client-a = {
      managementUrl = "https://netbird.client-a.com:443";  # override
    };
  };
};
```

Ports are auto-assigned starting at 51820 in alphabetical order of tunnel names.
Override with `port` on any tunnel if needed.

## Options

| Option | Default | Description |
|---|---|---|
| `enable` | `false` | Enable the module |
| `managementUrl` | `null` | Default management server URL for all tunnels |
| `adminUrl` | `null` | Default admin panel URL (defaults to `managementUrl`) |
| `useRoutingFeatures` | `"client"` | `none`, `client`, `server`, or `both` |
| `logLevel` | `"info"` | Log level for all tunnel daemons |
| `hardened` | `true` | Run daemons as dedicated system users |

### Per-tunnel options

| Option | Default | Description |
|---|---|---|
| `port` | auto | WireGuard listen port |
| `autoStart` | `true` | Start with the system |
| `setupKey` | `true` | Use SOPS-managed setup key for automated login |
| `managementUrl` | inherited | Override management URL for this tunnel |
| `adminUrl` | inherited | Override admin URL for this tunnel |

## SOPS secrets

The module expects a single SOPS-encrypted YAML file at:

```
<configDir>/hosts/<hostname>/secrets/netbird.yaml
```

### YAML structure

Each tunnel that has `setupKey = true` needs a corresponding entry:

```yaml
netbird:
    lab/setup_key: "YOUR-SETUP-KEY-HERE"
    client-a/setup_key: "YOUR-SETUP-KEY-HERE"
```

The key path follows the pattern `netbird/<tunnel-name>/setup_key`.

Setup keys are generated in the Netbird management dashboard under **Setup Keys**.
For automated/server deployments, reusable keys are convenient. For one-off machines,
use one-off keys.

## Impermanence

All tunnel state directories (`/var/lib/netbird-<name>`) are **always persisted**.

Each directory contains `config.json` which holds the WireGuard private key that
identifies this peer to the management server. Without it, a reboot would cause the
client to generate a new key and register as a brand new peer — orphaning the old
entry in the dashboard.

This applies regardless of whether a setup key is used. The setup key only handles
initial enrollment; peer identity is tied to the WireGuard key on disk.

## Desktop UI

The upstream module auto-enables `netbird-ui` when a graphical session is
detected.
