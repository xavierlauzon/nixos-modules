{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.host.feature.security.auditd.rules.docker;
in {
  options.host.feature.security.auditd.rules.docker = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Docker/Cilium container monitoring rules";
    };
  };

  config.security.audit.rules = mkIf cfg.enable [
    # =============================================================================
    # Docker Container Monitoring
    # =============================================================================

    # Docker daemon socket access
    "-w /var/run/docker.sock -p rwxa -k docker_socket"

    # Docker binary execution
    "-w /usr/bin/docker -p x -k docker_exec"
    "-a exit,always -F arch=b64 -S execve -F exe=/usr/bin/docker -k docker_commands"

    # Docker container directories
    "-w /var/lib/docker/ -p wa -k docker_data"
    "-w /etc/docker/ -p wa -k docker_config"

    # =============================================================================
    # Container Runtime Events
    # =============================================================================

    # Monitor container start/stop events (from docker logs)
    "-a exit,always -F arch=b64 -S open -S openat --exclude-arg=0x8000 -F a2=/var/lib/docker/containers -p r -k container_events"

    # =============================================================================
    # Cilium-specific Monitoring (eBPF)
    # =============================================================================

    # BPF map access for Cilium network policies
    "-a exit,always -F arch=b64 -S bpf -F cmd=0 -k cilium_bpf_map_create"     # BPF_MAP_CREATE
    "-a exit,always -F arch=b64 -S bpf -F cmd=1 -k cilium_bpf_map_lookup"     # BPF_MAP_LOOKUP_ELEM
    "-a exit,always -F arch=b64 -S bpf -F cmd=2 -k cilium_bpf_map_update"     # BPF_MAP_UPDATE_ELEM
    "-a exit,always -F arch=b64 -S bpf -F cmd=3 -k cilium_bpf_map_delete"     # BPF_MAP_DELETE_ELEM

    # Cilium agent monitoring (if running)
    "-w /var/lib/cilium/ -p wa -k cilium_data"
    "-w /run/cilium/ -p rwa -k cilium_run"

    # Hubble observability (Cilium's network observability tool)
    "-a exit,always -F arch=b64 -S open -S openat --exclude-arg=0x8000 -F a2=/var/log/hubble -p r -k hubble_logs"

    # =============================================================================
    # Container Image Operations
    # =============================================================================

    # Docker image pull/push operations (from docker logs)
    "-a exit,always -F arch=b64 -S open -S openat --exclude-arg=0x8000 -F a2=/var/lib/docker/image -p r -k image_operations"

    # =============================================================================
    # Container Privilege Escalation Prevention
    # =============================================================================

    # Monitor privileged container creation attempts
    "-a exit,always -F arch=b64 -S execve -F exe=/usr/bin/docker -F arg0=*--privileged* -k privileged_container"

    # =============================================================================
    # Docker Compose and Orchestration
    # =============================================================================

    # Docker compose execution
    "-w /usr/local/bin/docker-compose -p x -k docker_compose_exec"
    "-a exit,always -F arch=b64 -S execve -F exe=/usr/local/bin/docker-compose -k docker_compose_commands"

    # Kubernetes (if using with Docker)
    "-w /etc/kubernetes/ -p wa -k kubernetes_config"
    "-w /var/lib/kubelet/ -p rwa -k kubelet_data"
  ];
}
