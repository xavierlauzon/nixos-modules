{config, lib, ...}:
with lib;
{
  imports = [
    ./docker
    ./flatpak.nix
    ./rke2.nix
    ./virtd.nix
    ./waydroid.nix
  ];
}