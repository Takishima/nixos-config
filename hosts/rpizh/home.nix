# Standalone home-manager, for as long as the Pi runs Raspberry Pi OS:
#   home-manager switch --flake .#damien@rpizh
{ config, pkgs, ... }:
{
  imports = [ ../../home/damien/rpizh.nix ];

  home = {
    username = "damien";
    homeDirectory = "/home/damien";
    stateVersion = "26.11";
  };

  targets.genericLinux = {
    enable = true;
    gpu.enable = false;
  };

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  programs = {
    home-manager.enable = true;
    nh = {
      enable = true;
      flake = "${config.home.homeDirectory}/code/nix/nixos-config";
    };
  };
}
