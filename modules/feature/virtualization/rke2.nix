{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.host.feature.virtualization.rke2;
in
{
  options.host.feature.virtualization.rke2 = {
    enable = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Enable RKE2 (Rancher Kubernetes Engine 2) - A Kubernetes distribution that focuses on security and compliance within the U.S. Federal Government sector.
      '';
    };
    cluster = {
      bootstrapMode = mkOption {
        type = types.enum [ "initial" "server" "agent" ];
        description = ''
          Mode for bootstrapping the cluster:
          - initial: First server node that initializes the cluster
          - server: Additional control-plane nodes that join an existing cluster
          - agent: Worker nodes that join the cluster
        '';
        example = "initial";
      };
      serverURL = mkOption {
        default = null;
        example = "https://cluster-1.example.com:9345";
        type = types.nullOr types.str;
        description = ''
          URL of the RKE2 server node(s) to join.
          Required for server nodes joining an existing cluster and for agent nodes.
          Format: https://<server>:9345
        '';
      };
      nodeName = mkOption {
        default = cfg.network.dns.hostname;
        type = types.nullOr types.str;
        example = "node-1.example.com";
        description = ''
          The node name to register with the RKE2 server.
          If not specified, defaults to the system's hostname.
          Must be unique within the cluster.
        '';
      };
      nodeIP = mkOption {
        default = null;
        type = types.str;
        example = "192.168.1.1";
        description = ''
          IPv4/IPv6 addresses to advertise for this node.
          Used for inter-node communication and should be reachable by all other nodes.
          For multiple addresses, separate with commas.
        '';
      };
      nodeLabel = mkOption {
        default = null;
        type = types.nullOr types.str;
        description = ''
          Set a node's label.

          This option only adds labels at registration time, and can only be added once and not removed after that through rke2 commands.
          If you want to change node labels after node registration you should use kubectl. Refer to the official Kubernetes documentation for details on how to add labels.
        '';
      };
      nodeTaint = mkOption {
        default = null;
        type = types.nullOr types.str;
        example = "CriticalAddonsOnly=true:NoExecute";
        description = ''
          Set node taint for server nodes.

          This option only adds taints at registration time, and can only be added once and not removed after that through rke2 commands.
          If you want to change node taints after node registration you should use kubectl. Refer to the official Kubernetes documentation for details on how to add taints.
        '';
      };
    };
    networking = {
      clusterCidr = mkOption {
        default = "10.42.0.0/16";
        type = types.str;
        description = ''
          IPv4/IPv6 network CIDR to use for pod IPs.
          This is the subnet used for pod networking. Each pod will receive an IP from this range.
        '';
      };
      serviceCidr = mkOption {
        default = "10.43.0.0/16";
        type = types.str;
        description = ''
          IPv4/IPv6 network CIDR to use for service IPs.
          This is the subnet used for Kubernetes services when using kube-proxy.
        '';
      };
      clusterDns = mkOption {
        default = "10.43.0.10";
        type = types.str;
        description = ''
          IPv4 Cluster IP for coredns service. Should be in your service-cidr range.
          This IP address will be used by all pods in the cluster for DNS resolution.
        '';
      };
      clusterDomain = mkOption {
        default = "cluster.local";
        type = types.str;
        description = ''
          Cluster Domain name used for DNS queries within the cluster.
          All services and pods will be assigned DNS names under this domain.
        '';
      };
    };
    security = {
      tls = {
        san = mkOption {
          default = [];
          type = types.listOf types.str;
          description = ''
            Additional Subject Alternative Names (SANs) to add to the server's TLS certificate.
            Useful when accessing the Kubernetes API through different hostnames or IPs.
            Must be specified as a list of strings representing either IP addresses or DNS names.
          '';
          example = [ "k8s.example.com" "*.k8s.example.com" ];
        };
      };
      registry = {
        defaultRegistry = mkOption {
          default = null;
          type = types.nullOr types.str;
          description = ''
            System default registry to pull RKE2 images from.
            Prefix for all system images. Example: "registry.example.com:5000"
            Use this when your nodes don't have access to DockerHub.
          '';
          example = "registry.company.com:5000";
        };
        privateConfig = mkOption {
          default = null;
          type = types.nullOr types.path;
          description = ''
            Path to a registries.yaml file for configuring containerd private registry auth.
            The file should contain registry configurations in YAML format.
            See: https://docs.rke2.io/install/containerd_registry_configuration
          '';
          example = "/etc/rancher/rke2/registries.yaml";
        };
      };
    };
    advanced = {
      debug = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Enable debug logging for the RKE2 service.
          This increases verbosity of the logs and is useful for troubleshooting.
        '';
      };
      extraConfig = mkOption {
        default = [];
        type = types.listOf types.str;
        description = ''
          Extra arguments for the RKE2 service.
          Refer to the RKE2 documentation for available options. https://docs.rke2.io/reference/server_config
        '';
      };
      configPath = mkOption {
        default = null;
        type = types.nullOr types.str;
        description = ''
          Specify an alternate path for the rke2 config.yaml configuration file.
          Defaults to /etc/rancher/rke2/config.yaml.
        '';
      };
      dataDir = mkOption {
        default = null;
        type = types.nullOr types.str;
        description = ''
          Specify an alternate data directory for RKE2.
          Defaults to /var/lib/rancher/rke2.
        '';
      };
      disable = mkOption {
        default = [];
        type = types.listOf types.str;
        description = ''
          List of RKE2 packaged components to disable.
          Components listed here will not be deployed, and any existing components will be deleted.
          Available components: rke2-canal, rke2-coredns, rke2-ingress-nginx, rke2-metrics-server
        '';
        example = [ "rke2-ingress-nginx" "rke2-metrics-server" ];
      };
      cisHardening = mkOption {
        default = true;
        type = types.bool;
        description = ''
          Enable CIS (Center for Internet Security) Hardening for RKE2.
          Sets configurations and controls required to address Kubernetes benchmark controls.

          Note: After enabling, you may need to restart the systemd-sysctl service:
          sudo systemctl restart systemd-sysctl

          See: https://docs.rke2.io/security/hardening_guide
        '';
      };
    };
  };

  config = mkIf cfg.enable (
    let
      role = if cfg.cluster.bootstrapMode == "initial" then "server" else cfg.cluster.bootstrapMode;
      isServer = role == "server";
      isInitialServer = cfg.cluster.bootstrapMode == "initial";
      isJoiningCluster = cfg.cluster.bootstrapMode != "initial";

      servicesRke2Options =
        # Required base configuration
        {
          enable = true;
          role = role;
          tokenFile = config.sops.secrets.clusterToken.path;
          serverAddr = optionalString isJoiningCluster cfg.cluster.serverURL;
        }
        # Path configurations
        // optionalAttrs (cfg.advanced.configPath != null) { configPath = cfg.advanced.configPath; }
        // optionalAttrs (cfg.advanced.dataDir != null) { dataDir = cfg.advanced.dataDir; }
        # Node identity configurations
        // optionalAttrs (cfg.cluster.nodeName != null) { nodeName = cfg.cluster.nodeName; }
        // optionalAttrs (cfg.cluster.nodeIP != null) { nodeIP = cfg.cluster.nodeIP; }
        // optionalAttrs (cfg.cluster.nodeLabel != null) { nodeLabel = cfg.cluster.nodeLabel; }
        // optionalAttrs (cfg.cluster.nodeTaint != null) { nodeTaint = cfg.cluster.nodeTaint; }
        # Conditional features
        // optionalAttrs cfg.advanced.debug { debug = true; }
        // optionalAttrs (isServer && cfg.advanced.disable != []) { disable = cfg.advanced.disable; }
        // {
          # Flags configuration
          extraFlags = concatLists [
            # Server-only cluster networking configuration
            (optionals isServer [
              "--cluster-cidr=${cfg.networking.clusterCidr}"
              "--service-cidr=${cfg.networking.serviceCidr}"
              "--cluster-dns=${cfg.networking.clusterDns}"
              "--cluster-domain=${cfg.networking.clusterDomain}"
            ])
            # Registry configuration
            (optional (cfg.security.registry.defaultRegistry != null)
              "--system-default-registry=${cfg.security.registry.defaultRegistry}")
            (optional (cfg.security.registry.privateConfig != null)
              "--private-registry=${cfg.security.registry.privateConfig}")
            # TLS configuration
            (optionals (isServer && cfg.security.tls.san != [])
              (map (san: "--tls-san=${san}") cfg.security.tls.san))
            # Additional configuration
            cfg.advanced.extraConfig
          ];
        };

    in {
      assertions = [
        {
          assertion = cfg.cluster.bootstrapMode != null;
          message = "cluster.bootstrapMode must be set to either 'initial', 'server', or 'agent'.";
        }
        {
          assertion = ((cfg.cluster.bootstrapMode != "server" && cfg.cluster.bootstrapMode != "agent") || cfg.cluster.serverURL != null);
          message = "serverURL must be set when bootstrapMode is 'server' or 'agent'.";
        }
      ];

      environment.systemPackages = [
        pkgs.kubernetes-helm
        pkgs.kubectl
      ];

      services.rke2 = servicesRke2Options;

      sops.secrets = {
        clusterToken = {
          sopsFile = "${config.host.configDir}/hosts/common/secrets/rke2/clusterToken.yaml";
        };
      };
    }
  );
}

# Overview:
# This module deploys an RKE2 cluster on NixOS with support for:
# - Multi-master HA configuration
# - Worker nodes
# - Sops-nix secrets for cluster tokens
#
# Note: Initial cluster formation & server/agent registration may take up to 15 minutes.
#
# Usage Steps:
# 1. Generate cluster token:
#    openssl rand -hex 16 > token.txt
#    echo "data: \"$(cat token.txt)\"" > clusterToken.yaml
#    sops --encrypt --in-place clusterToken.yaml
#
# 2. Initial Server Node:
#    host.feature.virtualization.rke2.enable = true;
#    host.feature.virtualization.rke2.cluster.bootstrapMode = "initial";
#
# 3. Additional Server Nodes:
#    host.feature.virtualization.rke2.enable = true;
#    host.feature.virtualization.rke2.cluster.bootstrapMode = "server";
#    host.feature.virtualization.rke2.cluster.serverURL = "https://<initial-server-ip>:9345";
#
# 4. Agent Nodes (Workers):
#    host.feature.virtualization.rke2.enable = true;
#    host.feature.virtualization.rke2.cluster.bootstrapMode = "agent";
#    host.feature.virtualization.rke2.cluster.serverURL = "https://<server-ip>:9345";
#
# Verification:
# - Check nodes: sudo rke2 kubectl get nodes
# - Check pods: sudo rke2 kubectl get pods -A
# - Ensure all nodes are in Ready state