{ config, inputs, lib, outputs, pkgs, configDir, ... }:

let
  inherit (config.networking) hostName;
  hostsecrets = "${configDir}"+/hosts/${hostName}/secrets/secrets.yaml;
  commonsecrets = "${configDir}"+/hosts/common/secrets/secrets.yaml;
  isEd25519 = k: k.type == "ed25519";
  getKeyPath = k: k.path;
  keys = builtins.filter isEd25519 config.services.openssh.hostKeys;
  cfg = config.host.feature.secrets;
in
  with lib;
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  options = {
    host.feature.secrets = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables secrets support";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      age
      gnupg
      pinentry.out
      ssh-to-age
      ssh-to-pgp
      sops
    ];

    sops = {
      age.sshKeyPaths = map getKeyPath keys;
      secrets = {
        ${hostName} = {
          sopsFile = hostsecrets;
        };
        common = {
          sopsFile = commonsecrets;
        };
      };
      templates = {
        example = {
          name = "example.cfg";
          content = ''
            example_info = "${config.sops.placeholder.common}"
          '';
        };
      };
    };
  };
}
