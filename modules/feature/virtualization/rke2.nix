{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.host.feature.virtualization.rke2;

  # Define paths
  kubectlPath = "${pkgs.kubectl}/bin/kubectl";
  helmPath = "${pkgs.kubernetes-helm}/bin/helm";

in
{
  options.host.feature.virtualization.rke2 = {
    enable = mkOption {
      default = false;
      type = types.bool;
      description = "Enable RKE2 on this node.";
    };
    cluster = {
      bootstrapMode = mkOption {
        type = types.enum [ "initial" "server" "agent" ];
        description = "Mode for bootstrapping the cluster. Use 'initial' for first server, 'server' for additional control-plane nodes, 'agent' for worker nodes.";
      };
      serverURL = mkOption {
        default = null;
        type = types.nullOr types.str;
        description = "URL of an existing server node to join (required for server and agent modes).";
      };
      nodeName = mkOption {
        default = null;
        type = types.nullOr types.str;
        description = "Node name override.";
      };
      defaultLabel = mkOption {
        default = null;
        type = types.nullOr types.str;
        description = "Override default node label.";
      };
      nodeTaint = mkOption {
        default = null;
        type = types.nullOr types.str;
        description = ''
          Set node taint for server nodes (e.g., "CriticalAddonsOnly=true:NoExecute").
          Only applies to server/initial nodes.
        '';
        example = "CriticalAddonsOnly=true:NoExecute";
      };
      nodeIP = mkOption {
        default = null;
        type = types.str;
        description = "IPv4/IPv6 addresses to advertise for node.";
      };
    };
    networking = {
      clusterCidr = mkOption {
        default = "10.42.0.0/16";
        type = types.str;
        description = "Network CIDR to use for pod IPs.";
      };
      serviceCidr = mkOption {
        default = "10.43.0.0/16";
        type = types.str;
        description = "Network CIDR to use for services.";
      };
      clusterDns = mkOption {
        default = "10.43.0.10";
        type = types.str;
        description = "Cluster DNS IP address.";
      };
      clusterDomain = mkOption {
        default = "cluster.local";
        type = types.str;
        description = "Cluster Domain.";
      };
    };
    security = {
      tls = {
        san = mkOption {
          default = [];
          type = types.listOf types.str;
          description = "Additional Subject Alternative Names (SANs) to add to the TLS certificate.";
          example = [ "k8s.example.com" "*.k8s.example.com" ];
        };
      };
      registry = {
        defaultRegistry = mkOption {
          default = null;
          type = types.nullOr types.str;
          description = "Set a system default registry for system images.";
        };
        privateConfig = mkOption {
          default = null;
          type = types.nullOr types.path;
          description = "Path to a private registries.yaml file for containerd.";
        };
      };
    };
    advanced = {
      debug = mkOption {
        default = false;
        type = types.bool;
        description = "Enable debug logging for RKE2.";
      };
      serverConfig = mkOption {
        default = [];
        type = types.listOf types.str;
        description = "Extra arguments for the RKE2 server.";
      };
      agentConfig = mkOption {
        default = [];
        type = types.listOf types.str;
        description = "Extra arguments for the RKE2 agent.";
      };
      ipPools = mkOption {
        default = [];
        type = types.listOf types.str;
        description = "List of CIDR ranges for IP pools.";
      };
      resources = {
        apiServer = mkOption {
          default = {
            limits = { cpu = "2"; memory = "1Gi"; };
            requests = { cpu = "500m"; memory = "512Mi"; };
          };
          type = types.submodule {
            options = {
              limits = mkOption {
                type = types.attrsOf types.str;
                description = "Resource limits for the API server.";
              };
              requests = mkOption {
                type = types.attrsOf types.str;
                description = "Resource requests for the API server.";
              };
            };
          };
          description = "Resource limits and requests for the Kubernetes API server.";
        };
        controllerManager = mkOption {
          default = {
            limits = { cpu = "1"; memory = "1Gi"; };
            requests = { cpu = "200m"; memory = "256Mi"; };
          };
          type = types.submodule {
            options = {
              limits = mkOption {
                type = types.attrsOf types.str;
                description = "Resource limits for the controller manager.";
              };
              requests = mkOption {
                type = types.attrsOf types.str;
                description = "Resource requests for the controller manager.";
              };
            };
          };
          description = "Resource limits and requests for the Kubernetes controller manager.";
        };
      };
    };
  };

  config = mkIf cfg.enable (
    let
      role = if cfg.cluster.bootstrapMode == "initial" then "server" else cfg.cluster.bootstrapMode;
      isServer = role == "server";
      isInitialServer = cfg.cluster.bootstrapMode == "initial";
      isJoiningNode = cfg.cluster.bootstrapMode != "initial";

      finalNodeName = cfg.cluster.nodeName or config.host.network.dns.hostname;

      # Update service configuration
      servicesRke2Options = {
        enable = true;
        role = role;
        debug = cfg.advanced.debug;
        nodeName = finalNodeName;
        nodeLabel = optionals (cfg.cluster.defaultLabel != null) [ cfg.cluster.defaultLabel ];
        nodeTaint = optionals (isServer && cfg.cluster.nodeTaint != null)
          [ cfg.cluster.nodeTaint ];
        nodeIP = cfg.cluster.nodeIP;

        tokenFile = if isJoiningNode then
          (if role == "agent" then config.sops.secrets.agentToken.path else config.sops.secrets.clusterToken.path)
        else null;
        serverAddr = if isJoiningNode then cfg.cluster.serverURL else "";

        extraFlags = [
          "--cluster-cidr=${cfg.networking.clusterCidr}"
          "--service-cidr=${cfg.networking.serviceCidr}"
          "--cluster-dns=${cfg.networking.clusterDns}"
          "--cluster-domain=${cfg.networking.clusterDomain}"
        ] ++
        (optionals (cfg.security.registry.defaultRegistry != null) [
          "--system-default-registry=${cfg.security.registry.defaultRegistry}"
        ]) ++
        (optionals (cfg.security.registry.privateConfig != null) [
          "--private-registry=${cfg.security.registry.privateConfig}"
        ]) ++
        (optionals (isServer && cfg.security.tls.san != []) (
          map (san: "--tls-san=${san}") cfg.security.tls.san
        )) ++
        (if role == "server" then cfg.advanced.serverConfig else cfg.advanced.agentConfig);
      };

    in {
      assertions = [
        {
          assertion = ((cfg.cluster.bootstrapMode != "server" && cfg.cluster.bootstrapMode != "agent") || cfg.cluster.serverURL != null);
          message = "serverURL must be set when bootstrapMode is 'server' or 'agent'.";
        }
        {
          assertion = (cfg.cluster.nodeTaint == null || isServer);
          message = "nodeTaint can only be set for server nodes.";
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
        agentToken = {
          sopsFile = "${config.host.configDir}/hosts/common/secrets/rke2/agentToken.yaml";
        };
      };
    }
  );
}
# TODO
# 1. external etcd support (maybe? if rke2 implements it just as reliably then no)
# 2. true multi-master support
# 3. fix tls certs
# 4. Test with multiple master nodes and workers



# Overview:
# This module deploys an RKE2 cluster on NixOS with support for:
# - Multi-master HA configuration
# - Worker nodes
# - Sops-nix secrets for cluster token and TLS
# - Cert-Manager integration
# - Rancher UI deployment
#
# Key Features:
# - Modular configuration with logical grouping (cluster, networking, rancher, etc.)
# - Automatic HA etcd clustering with --cluster-init
# - Conditional Helm charts installation with idempotency
# - Comprehensive TLS management (sops-encrypted or Let's Encrypt)
#
# Usage Steps:
# 1. Generate cluster token:
#    openssl rand -hex 16 > token.txt
#    echo "data: \"$(cat token.txt)\"" > clusterToken.yaml
#    sops --encrypt --in-place clusterToken.yaml
#
# 2. Initial Master:
#    cluster.bootstrapMode = "initial"
#    rancher.enable = true
#    rancher.hostname = "rancher.example.com"
#    rancher.tls.letsEncryptEmail = "admin@example.com"
#
# 3. Additional Masters:
#    cluster.bootstrapMode = "server"
#    cluster.serverURL = "https://<master-lb-ip>:6443"
#
# 4. Workers:
#    cluster.bootstrapMode = "agent"
#    cluster.serverURL = "https://<master-lb-ip>:6443"
#
# Verification:
# - Check nodes: sudo rke2 kubectl get nodes
# - Check pods: sudo rke2 kubectl get pods -A
# - Access Rancher UI at configured hostname#    cluster.bootstrapMode = "agent"#    cluster.serverURL = "https://<master-lb-ip>:6443"## Verification:# - Check nodes: sudo rke2 kubectl get nodes# - Check pods: sudo rke2 kubectl get pods -A# - Access Rancher UI at configured hostname