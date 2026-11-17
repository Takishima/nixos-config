# Input URL recipes

## GitHub / GitLab

```nix
inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
inputs.repo.url    = "github:user/repo";
inputs.repo.url    = "github:user/repo/branch-or-tag";
inputs.repo.url    = "github:user/repo/abc123def456";  # specific rev

inputs.proj.url    = "gitlab:group/project";
inputs.proj.url    = "gitlab:group/subgroup/project";
inputs.proj.url    = "gitlab:group/project?host=gitlab.company.com";
```

## Plain git

```nix
inputs.repo.url = "git+https://example.com/repo.git";
inputs.repo.url = "git+https://example.com/repo.git?ref=main";
inputs.repo.url = "git+https://example.com/repo.git?rev=abc123";

inputs.repo.url = "git+ssh://git@example.com/repo.git";

inputs.local.url = "git+file:///path/to/repo";
```

Git over SSH needs ssh-agent / key access on the eval machine. CI typically
needs an SSH deploy key or a token-based HTTPS URL.

## Path

```nix
inputs.mylib.url = "path:/absolute/path/to/dir";
inputs.utils.url = "path:./relative/path";       # relative to flake.nix
```

Path inputs are *not* hashed in `flake.lock` the same way as remote inputs;
they're re-read every eval. Good for vendored sub-projects.

## Tarball

```nix
inputs.archive.url = "https://example.com/archive.tar.gz";
inputs.archive.url = "https://example.com/archive.tar.gz?narHash=sha256-...";
```

`narHash=` pins the content. Without it, the lock pins the URL contents at
first lock-time.

## Flake registry

```nix
inputs.nixpkgs.url = "flake:nixpkgs";   # uses the registry entry
```

`nix registry list` shows the entries. The default registry maps
`nixpkgs` → `github:NixOS/nixpkgs/nixpkgs-unstable`.

## `follows` to deduplicate

When `inputs.X` already depends on `nixpkgs`, point its nixpkgs at yours:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

Without this, your closure can carry several different `nixpkgs` revisions.

## Private repos

`github:` and `gitlab:` URL forms use a personal access token if one is
provided:

```bash
export GITHUB_TOKEN=ghp_…       # or in ~/.config/nix/nix.conf:
# access-tokens = github.com=ghp_…
```

For GitLab self-hosted: `gitlab:group/project?host=gitlab.example.com` and
configure `access-tokens = gitlab.example.com=glpat_…` similarly.

For `git+ssh://`, ssh-agent must be running and have the key loaded.

## `flake = false`

When the input is a plain repo (not a flake) you still want as a source:

```nix
inputs.mysrc = {
  url   = "github:user/non-flake-repo";
  flake = false;
};
```

Use the result directly as a source tree:
`self.callPackage ./pkg.nix { src = mysrc; }`.

## Pinning by `narHash`

Sometimes you want to pin a tarball or path input to a specific content
hash without committing the URL contents to your `flake.lock`:

```nix
inputs.thing.url = "https://example.com/thing.tar.gz?narHash=sha256-abc…";
```

Useful for vendor-mirror URLs that may serve different content from the
same URL over time.

## Common pitfalls

- Hard-coded SHA in URL means lock won't change on `nix flake update`. Use
  a branch / tag ref if you want updates to be discoverable.
- `git+file:` inputs without `?rev=` re-eval on every change; commit and
  push if reproducibility matters.
- Don't put secrets in URLs. Configure tokens via `access-tokens` config
  instead.
