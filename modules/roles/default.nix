{lib, ...}:

with lib;
{
  imports = [
    ./desktop.nix
    ./laptop
    ./minimal.nix
    ./server.nix
    ./vm.nix
  ];

  options = {
    host.role = mkOption {
      type = types.enum [
        "desktop"   # Typical Workstation
        "laptop"    # Workstation with differnet power profiles
        "minimal"   # Bare bones
        "server"    #
        "vm"        # Some sort of virtual machine, that may have a combo of desktop or laptop
      ];
    };
  };
}
