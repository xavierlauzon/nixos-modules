{lib, ...}:

with lib;
{
  imports = [
    ./fluent-bit.nix
    ./herald.nix
    ./logrotate.nix
    ./monit.nix
    ./ssh.nix
    ./syncthing.nix
    ./vscode_server.nix
    ./zabbix_agent.nix
    ./zeroplex.nix
  ];
}