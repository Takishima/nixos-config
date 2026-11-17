# sops, with an SSH private key as identity, as sops-nix uses it.
{
  writeShellApplication,
  sops,
  ssh-to-age,
}:
writeShellApplication {
  name = "sops-host";
  runtimeInputs = [
    sops
    ssh-to-age
  ];
  text = ''
    key=''${SOPS_SSH_KEY:-/etc/ssh/ssh_host_ed25519_key}
    if [ -r "$key" ]; then
      SOPS_AGE_KEY=$(ssh-to-age -private-key -i "$key")
    else
      SOPS_AGE_KEY=$(sudo "$(command -v ssh-to-age)" -private-key -i "$key")
    fi
    export SOPS_AGE_KEY
    exec sops "$@"
  '';
}
