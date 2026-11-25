# NixOS module: Damien's account on a server.
{ lib, ... }:
{
  users.users.damien = {
    isNormalUser = true;
    uid = 1000;
    description = "Damien Nguyen";
    openssh.authorizedKeys.keys = lib.attrVals [
      "termius-rpi"
      "homelinux-rpi"
    ] (import ./ssh-keys.nix);
  };
  home-manager.users.damien = ./minimal.nix;

  my.hardened.sshUsers = [ "damien" ];
}
