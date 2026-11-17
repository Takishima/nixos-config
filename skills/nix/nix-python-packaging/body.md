# Nix Python packaging

Use this skill when packaging a Python library or application — selecting
`buildPythonPackage` vs `buildPythonApplication`, modern
`pyproject = true` declarations, fetching source, configuring tests,
managing native dependencies.

If the package depends on PyTorch / TensorFlow / JAX / any CUDA stack, jump
to `nix-cuda-packaging` instead — those **must** build from source.

## Library vs application

| Use | When |
|-----|------|
| `buildPythonPackage` | Library — depends will be visible to other Python packages |
| `buildPythonApplication` | End-user CLI / app — dependencies are isolated, not propagated |

Apps get their own bin/ wrapped against their own Python; libraries
contribute to the `python3.pkgs.*` set.

## Modern skeleton (PEP 517 / 518)

```nix
{ lib, buildPythonPackage, fetchPypi, setuptools, requests, numpy, pytestCheckHook }:

buildPythonPackage rec {
  pname   = "my-package";
  version = "1.0.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-...";
  };

  build-system = [ setuptools ];        # replaces nativeBuildInputs for the build backend
  dependencies = [ requests numpy ];    # replaces propagatedBuildInputs

  optional-dependencies = {
    dev  = [ pytestCheckHook ];
    docs = [ /* sphinx, … */ ];
  };

  nativeCheckInputs = [ pytestCheckHook ];
  pythonImportsCheck = [ "my_package" ];

  meta = {
    description = "What this does";
    homepage    = "https://github.com/user/my-package";
    license     = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}
```

Three modern-vs-legacy points:

- `pyproject = true` activates the PEP-517 build path. Don't use
  `format = "setuptools"` in new packages.
- `build-system` (not `nativeBuildInputs`) for the build backend
  (`setuptools`, `hatchling`, `poetry-core`, `flit-core`, …).
- `dependencies` (not `propagatedBuildInputs`) for runtime imports.
- `optional-dependencies` mirrors PEP 621 extras.

## fetchPypi vs fetchFromGitHub

@{context7_tip}### fetchPypi

```nix
src = fetchPypi {
  inherit pname version;
  hash = "sha256-...";
};
```

PyPI normalizes package names — `package-name` becomes `package_name` in
the tarball. `fetchPypi` handles that automatically: pass the PyPI name in
`pname`.

For sdists with unusual names: pass `pname` explicitly and override the
URL construction with `format = "wheel"; dist = …; python = …; abi = …; platform = …;` — but **only** for pure-Python `py3-none-any` wheels. Never
fetch a platform-specific wheel; build from source instead.

### fetchFromGitHub

```nix
src = fetchFromGitHub {
  owner = "user";
  repo  = pname;
  rev   = "v${version}";   # or refs/tags/v${version}
  hash  = "sha256-...";
};
```

Use when:

- PyPI is missing the sdist (some projects don't upload sdists).
- You need a non-tagged commit / branch.
- The PyPI sdist excludes tests or other files needed for the build.

## Testing

```nix
nativeCheckInputs = [ pytestCheckHook ];

# Optional knobs:
pytestFlagsArray   = [ "-v" "--ignore=tests/integration" ];
disabledTests      = [ "test_flaky" "test_requires_network" ];
disabledTestPaths  = [ "tests/slow" ];
pythonImportsCheck = [ "my_package" "my_package.cli" ];
```

`pytestCheckHook` runs pytest with the package's own test discovery —
preferable to writing a custom `checkPhase` unless the project has a
non-standard runner.

Skip tests entirely (last resort):

```nix
doCheck = false;
```

Document *why* with a comment when you do.

## Native dependencies (C extensions)

For packages with C extensions (numpy, lxml, cryptography, etc.):

```nix
build-system = [ setuptools wheel ];

nativeBuildInputs = [
  pkg-config
];

buildInputs = [
  libxml2.dev
  zlib.dev
  openssl
];

# When propagation is needed because of dlopen at runtime:
dependencies = [
  libxml2     # exposes .so to consumers
];
```

`build-system` is for the *Python* build backend; classic
`nativeBuildInputs` is still where C compilers, pkg-config, autoreconfHook
go.

## Dependency hooks

```nix
# Loosen upstream version pins
pythonRelaxDeps = [ "numpy" "requests" ];   # or `true` for all

# Drop dev-only deps the build doesn't actually need
pythonRemoveDeps = [ "pytest-runner" ];
```

No corresponding hook entry in `nativeBuildInputs` — these are top-level
attribute names that the python-builder picks up automatically.

## Python version conditionals

```nix
dependencies = [ requests numpy ]
  ++ lib.optionals (pythonOlder "3.9")   [ importlib-metadata ]
  ++ lib.optionals (pythonAtLeast "3.10") [ new-feature-pkg ];
```

`pythonOlder` / `pythonAtLeast` come from the Python builder scope —
they're in scope inside the function args list.

## Wiring into an overlay / package set

```nix
final: prev: {
  python3 = prev.python3.override {
    packageOverrides = pyFinal: pyPrev: {
      my-package = pyPrev.callPackage ./my-package.nix { };
    };
  };
}
```

Now `pkgs.python3.pkgs.my-package` is available, as are
`pkgs.python3.withPackages (ps: [ ps.my-package ])` and similar consumers.

See `nix-overlays` → `references/scoped-overlays.md` for the full pattern.

## Common errors

| Error | First thing to try |
|-------|--------------------|
| `ModuleNotFoundError: No module named 'foo'` at runtime | Missing from `dependencies` (not `build-system`) |
| `Requested distribution not found: foo>=2` | Version pin upstream too tight — add to `pythonRelaxDeps` |
| `Could not find a version that satisfies the requirement` | Build backend missing — add to `build-system` (`setuptools`, `hatchling`, etc.) |
| `error: ... cannot find -lxml2` | C library missing — add to `buildInputs` and `dependencies` |
| `ConnectionError` during tests | Network access required; add to `disabledTests` or `disabledTestPaths` |
| `hash mismatch` on src | Use `lib.fakeHash`, rebuild, copy the actual hash |

## Don't do this

- `format = "setuptools"` in new code → use `pyproject = true` + `build-system`.
- Fetching a platform-specific wheel (`manylinux_*`, `cp310-cp310-linux_x86_64`)
  with `format = "wheel"` → fragile and breaks reproducibility. Use the sdist.
- Pre-built wheels for any CUDA / PyTorch / TF / JAX dependency → see
  `nix-cuda-packaging`.
- `nativeBuildInputs = [ setuptools ]` in modern code → use `build-system = [ setuptools ];`.
- `propagatedBuildInputs` for what should be `dependencies`.

## References

- [references/advanced.md](references/advanced.md) — C extensions,
  cffi / pybind11 / cython, multi-output Python packages, namespace
  packages, applications with bundled data, test-runner alternatives.
- For overlay-scoped Python package sets see `nix-overlays`.
- For CUDA / GPU Python packages see `nix-cuda-packaging`.
- For validation tooling see `nix-quality`.
