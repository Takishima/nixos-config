# Advanced Python packaging

## C extensions

```nix
buildPythonPackage rec {
  pyproject = true;

  build-system = [ setuptools wheel ];

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    libxml2.dev
    zlib.dev
    openssl
  ];

  dependencies = [
    # Anything imported via the compiled .so or dlopen'd at runtime
  ];

  # Compiler flags when upstream's setup.py needs them
  env.NIX_CFLAGS_COMPILE = "-I${libxml2.dev}/include/libxml2";
}
```

For `setup.py` projects that build C code via distutils, ensure the include
path is exported. `pkg-config` in `nativeBuildInputs` covers most cases.

## cffi / pybind11 / cython

```nix
build-system = [
  setuptools wheel
  cffi              # for cffi-based bindings
  pybind11          # for pybind11 modules
  cython            # for Cython-generated C
];
```

`cffi` also needs to be in `dependencies` because the runtime cffi loader
imports it.

## Namespace packages

For projects splitting one namespace across multiple distributions
(e.g. `zope.*`, `azure.*`):

```nix
buildPythonPackage {
  # Tell setuptools where the namespace lives
  pyproject = true;
  build-system = [ setuptools ];

  # If pkg_resources-style namespace, drop the marker file in postInstall
  postInstall = ''
    rm -f $out/${python.sitePackages}/azure/__init__.py
  '';
}
```

The modern PEP 420 "implicit namespace" packages don't need this; only the
legacy `pkg_resources.declare_namespace` style does.

## Applications with bundled data

```nix
buildPythonApplication rec {
  pname = "myapp";
  version = "1.0.0";
  pyproject = true;
  src = …;

  build-system = [ setuptools ];
  dependencies = [ click jinja2 ];

  postInstall = ''
    install -Dm644 share/applications/myapp.desktop \
      $out/share/applications/myapp.desktop
    install -Dm644 share/icons/myapp.svg \
      $out/share/icons/hicolor/scalable/apps/myapp.svg
  '';

  # Bash/Zsh completion
  nativeBuildInputs = [ installShellFiles ];
  postFixup = ''
    installShellCompletion --cmd myapp \
      --bash <($out/bin/myapp completion bash) \
      --zsh  <($out/bin/myapp completion zsh) \
      --fish <($out/bin/myapp completion fish)
  '';

  meta.mainProgram = "myapp";
}
```

`buildPythonApplication` wraps the script with the *exact* Python it was
built against, so deps aren't visible to the system Python. That's the
point of using application form over package form.

## Multi-output Python packages

Rare but useful for very large libs (e.g. testing extras):

```nix
buildPythonPackage {
  outputs = [ "out" "tests" ];

  postInstall = ''
    mkdir -p $tests
    mv tests $tests/
  '';
}
```

Most Python packages don't benefit — the runtime Python files are tiny
relative to deps.

## Alternative test runners

When `pytestCheckHook` doesn't apply (project uses unittest, nose, tox,
custom):

```nix
checkPhase = ''
  runHook preCheck
  python -m unittest discover -s tests
  runHook postCheck
'';

nativeCheckInputs = [ /* test deps */ ];
```

Avoid invoking `tox` directly inside the build — `tox` reaches for its own
venv and conflicts with the Nix Python. Run the underlying pytest /
unittest invocation that `tox.ini` would call.

## Disabling Python sandbox checks

Sometimes upstream tests probe `pip install`, network, or PyPI:

```nix
disabledTestPaths = [
  "tests/test_network.py"
  "tests/integration"
];

disabledTests = [
  "test_pip_install"
  "test_requires_network"
];
```

Prefer `disabledTests` over `pytestFlagsArray = ["-k not foo"]` —
`disabledTests` is greppable; `-k` expressions are fragile.

## Pre-1.0 packages with broken metadata

```nix
postPatch = ''
  substituteInPlace pyproject.toml \
    --replace 'requires-python = ">=3.11"' 'requires-python = ">=3.10"'
'';

# Or relax at the dependency level
pythonRelaxDeps = [ "numpy" ];
```

`pythonRelaxDeps` removes upper bounds (`numpy>=1.21,<2`) but keeps lower
bounds. `pythonRemoveDeps` for completely dropping a dep.

## Lockfile-driven builds (poetry / PDM / hatch)

For projects with `poetry.lock` / `pdm.lock`:

```nix
inputs.poetry2nix.url = "github:nix-community/poetry2nix";

# in a derivation
mkPoetryApplication { projectDir = ./.; }
```

For modern `uv`-managed projects, see the nixpkgs `uv2nix` work (still
moving fast — check current state when you need it). The hand-written
`buildPythonPackage` approach above is the boring, reliable default.

## Common pitfalls

- Forgetting `pyproject = true` on a `pyproject.toml` project. Build will
  fall through to legacy setuptools path, fail with confusing errors.
- Setting `format = "wheel"` for a `manylinux` wheel. Compiles a fixed
  glibc / libstdc++ assumption into the package; fragile, non-reproducible.
  Use the sdist.
- Putting `pytest` in `dependencies` instead of `nativeCheckInputs`. Leaks
  pytest into every downstream consumer's closure.
- Using `python3.pkgs.callPackage` from inside an attrset that's already
  inside `python3Packages` — double scope, recurses or fails.
