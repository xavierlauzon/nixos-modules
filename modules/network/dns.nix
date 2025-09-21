{config, lib, pkgs, ...}:

let
  defaultdns.domain =
  if (config.host.network.dns.domain == "null")
  then true
  else false;
  defaultHostname =
  if (config.host.network.dns.hostname == "null")
  then true
  else false;

  cfg = config.host.network.dns;
in
  with lib;
{
  options = {
    host.network.dns = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable DNS configuration.";
      };
      servers = mkOption {
        type = types.listOf types.str;
        default = [ "1.1.1.1" "1.0.0.1" ];
        description = "Set the DNS server in use";
      };
      domain = mkOption {
        type = types.str;
        default = "null";
        description = "Domain name of the system";
      };
      search = mkOption {
        type = types.listOf types.str;
        default = "null";
        description = "Search domains of the system";
      };
      hostname = mkOption {
        type = types.str;
        default = "null";
        description = "Hostname of the system";
      };
      stub = mkOption {
        type = types.bool;
        default = true;
        description = "Enable systemd-resolved's DNSStubListener. May cause issues when running DNS servers.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      { assertion = !defaultdns.domain
; message = "[host.network.dns.domain] Enter a domain name to add network uniqueness";}
      { assertion = !defaultHostname; message = "[host.network.dns.hostname] Enter a hostname to add network uniqueness";}
    ];

    networking = {
      domain = cfg.domain;
      search = cfg.search;
      hostName = cfg.hostname;
      nameservers = cfg.servers;
    };

    services.resolved = {
      enable = true;
      extraConfig = mkIf (cfg.stub == false) "DNSStubListener=no";
    };
  };
}