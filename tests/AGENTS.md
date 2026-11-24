# tests

Every `*.nix` file here but `default.nix` becomes a check: adding the file is all
the wiring. README.md, "Update", has the commands. The tests need KVM; without
`/dev/kvm`, evaluate the check's `drvPath` instead and leave the run to CI.

## Shape of a test

A test is a `lib.nixos.runTest` module: `name`, `nodes`, `testScript`. It gets
`self`, `sshKeys` (nixpkgs' throwaway SSH key pair), `fixtureSecrets` (the value
of `my.secrets` for the fixture below) and `checkPassword <password> <hash>`.
`ssh-server.nix` is the one to copy.

- Nodes import the modules as another flake would: `self.nixosModules.default`,
  or the single modules under test. Never a path into `modules/`.
- Test what the option promises, from outside the machine where that is the
  point: the port answers, the key logs in, the password is refused.
- Test the refusal as well as the success. A hardening test that only shows the
  right key working has shown nothing.
- One `with subtest("...")` per promise, named as a sentence that is true when
  it passes.
- Wait for a unit or a port (`wait_for_unit`, `wait_for_open_port`), never
  `sleep`.
- An assertion carries the output it judged: `assert status != 0, out`.

## Secrets in tests

`fixtures/secrets.yaml` is encrypted to nixpkgs' test SSH key, which stands in
for the host key. The header of `secrets.nix` lists what it holds.

- No real secret, and no key of a real host, in this directory.
- A test that needs a new key: you cannot write it without `sops`. Say which key
  and value to add, and add it to the list in `secrets.nix`.
- Also test the module with no sops file, as a freshly installed host has.
