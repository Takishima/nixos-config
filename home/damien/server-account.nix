# NixOS module: Damien's account on a server. Every key in ssh-keys.nix logs in.
{ lib, ... }:
{
  users.users.damien = {
    isNormalUser = true;
    uid = 1000;
    description = "Damien Nguyen";
    openssh.authorizedKeys.keys = lib.attrValues (import ./ssh-keys.nix);
  };
  home-manager.users.damien = ./minimal.nix;

  my.hardened.sshUsers = [ "damien" ];
}
