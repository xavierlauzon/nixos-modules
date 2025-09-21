{lib, ...}:

with lib;
{
  imports = [
    ./bash.nix
    ./bind.nix
    ./binutils.nix
    ./busybox.nix
    ./comma.nix
    ./coreutils.nix
    ./curl.nix
    ./diceware.nix
    ./direnv.nix
    ./dust.nix
    ./e2fsprogs.nix
    ./fzf.nix
    ./git.nix
    ./htop.nix
    ./iftop.nix
    ./inetutils.nix
    ./iotop.nix
    ./kitty.nix
    ./less.nix
    ./links.nix
    ./liquidprompt.nix
    ./lsof.nix
    ./mtr.nix
    ./nano.nix
    ./ncdu.nix
    ./openssl.nix
    ./pciutils.nix
    ./psmisc.nix
    ./rclone.nix
    ./ripgrep.nix
    ./rsync.nix
    ./strace.nix
    ./tmux.nix
    ./tree.nix
    ./wget.nix
    ./zoxide.nix
  ];
}
