{config, lib, pkgs, ...}:

let
  defaultDomainname =
  if (config.host.network.domainname == "null")
  then true
  else false;
in
  with lib;
{
  options = {
    host.network.domainname = mkOption {
      type = with types; str;
      default = "null";
      description = "Domain name of system";
    };
    host.network.domainsearch = mkOption {
      type = types.listOf types.str;
      default = "null";
      description = "Domain name of system";
    };
  };

  config = {
    assertions = [
      {
        assertion = !defaultDomainname;
        message = "[host.network.domainname] Enter a domain name to add network uniqueness";
      }
    ];

    networking = {
      domain = config.host.network.domainname;
      search = config.host.network.domainsearch;
    };
  };
}