{lib, ...}:

with lib;
{
  imports = [
    ./clamav.nix
    ./fluentbit.nix
    ./llng-handler.nix
    ./openldap.nix
    ./postfix-relay.nix
    ./restic.nix
    ./s3ql.nix
    ./socket-proxy.nix
    ./traefik-internal.nix
    ./traefik.nix
    ./unbound.nix
    ./zabbix-proxy.nix
  ];
}
