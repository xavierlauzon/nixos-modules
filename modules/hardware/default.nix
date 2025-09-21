{lib, ...}:

with lib;
{
  imports = [
    ./cpu
    ./gpu
    ./android.nix
    ./backlight.nix
    ./bluetooth.nix
    ./fingerprint.nix
    ./firmware.nix
    ./keyboard.nix
    ./lid.nix
    ./printing.nix
    ./raid.nix
    ./scanner.nix
    ./sound.nix
    ./touchpad.nix
    ./webcam.nix
    ./wireless.nix
    ./yubikey.nix
  ];
}
