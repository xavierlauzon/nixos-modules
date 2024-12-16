{config, lib, ...}:
with lib;
{
  imports = [
    ./docker.nix
    ./flatpak.nix
    ./rke2.nix
    ./virtd.nix
    ./waydroid.nix
  ];
}