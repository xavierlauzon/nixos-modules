{lib, ...}:

with lib;
{
  imports = [
    ./dns.nix
    ./firewall
    ./vpn
    ./wired.nix
  ];
}
