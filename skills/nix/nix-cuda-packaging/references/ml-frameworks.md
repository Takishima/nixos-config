# ML framework patterns

## PyTorch extensions

Extensions are Python packages that compile against a specific torch's
ABI (libtorch + CUDA). The extension must:

1. Use the *same* `cudaPackages` as the host torch.
1. Use the *same* `TORCH_CUDA_ARCH_LIST` (or a subset) as torch was built
   with — otherwise kernels are missing for some devices.

```nix
{ buildPythonPackage, fetchPypi, setuptools, cudaPackages, torch, python }:

buildPythonPackage rec {
  pname = "torch-extension"; version = "1.0.0";
  pyproject = true;
  src = fetchPypi { inherit pname version; hash = "sha256-..."; };

  preferWheel = false;

  build-system = [ setuptools ];

  nativeBuildInputs = [
    cudaPackages.cuda_nvcc
  ];

  buildInputs = [
    cudaPackages.cudatoolkit
  ];

  dependencies = [ torch ];

  preBuild = ''
    export CUDA_HOME="${cudaPackages.cudatoolkit}"
    export TORCH_CUDA_ARCH_LIST="${torch.cudaCapabilities or torch.TORCH_CUDA_ARCH_LIST}"
    export PYTHONPATH="${torch}/${python.sitePackages}:$PYTHONPATH"
  '';

  doCheck = false;
  pythonImportsCheck = [ "torch_extension" ];
}
```

The `PYTHONPATH` trick is occasionally needed when upstream's `setup.py`
imports torch to discover its include paths. Most modern extensions don't
need it; add only if the build complains about not finding torch.

## TensorFlow ops

Custom TF ops are compiled against `tensorflow`'s own libtensorflow + CUDA:

```nix
buildPythonPackage rec {
  pname = "tf-extension"; pyproject = true;
  preferWheel = false;

  build-system = [ setuptools ];
  nativeBuildInputs = [ cudaPackages.cuda_nvcc ];

  buildInputs = [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
  ];

  dependencies = [ tensorflow ];

  preBuild = ''
    export CUDA_HOME="${cudaPackages.cudatoolkit}"
    export TF_CUDA_PATHS="${cudaPackages.cudatoolkit}"
    export TF_NEED_CUDA=1
    export TF_CUDA_VERSION="${cudaPackages.cudatoolkit.version}"
    export TF_CUDNN_VERSION="${cudaPackages.cudnn.version}"
  '';
}
```

TF is more environment-variable-driven than PyTorch — every CUDA-relevant
detail wants its own `TF_*` env var. nixpkgs's tensorflow itself documents
the full set.

## JAX custom calls

JAX `pjit` / `jit` custom-call libraries link against XLA + CUDA. Patterns
mirror TF more than PyTorch:

```nix
buildPythonPackage rec {
  pname = "jax-extension"; pyproject = true;
  preferWheel = false;
  build-system = [ setuptools ];
  nativeBuildInputs = [ cudaPackages.cuda_nvcc ];
  buildInputs = [ cudaPackages.cudatoolkit cudaPackages.cudnn ];
  dependencies = [ jax jaxlib ];
  preBuild = ''
    export CUDA_HOME="${cudaPackages.cudatoolkit}"
    export JAX_PLATFORMS=cuda
  '';
}
```

`jaxlib` is the CUDA-bearing component — `jax` is pure-Python. Be sure
`jaxlib` came from source (nixpkgs builds it that way) and not a wheel.

## TensorRT

`cudaPackages.tensorrt` is closed-source NVIDIA — it's available in
nixpkgs but requires accepting NVIDIA's EULA via `cudaSupport = true` +
`config.allowUnfree = true`:

```nix
buildInputs = [
  cudaPackages.tensorrt
  cudaPackages.cudatoolkit
];
```

The closure will pull the unfree blob. Make sure your nixpkgs is
configured with `allowUnfreePredicate` or `allowUnfree = true`.

## NCCL

Multi-GPU collectives:

```nix
nativeBuildInputs = [ cudaPackages.nccl ];   # also need in buildInputs sometimes
buildInputs       = [ cudaPackages.nccl ];
```

NCCL is open-source; no unfree gate.

## Inheriting `cudaPackages` from upstream

The cleanest way to keep CUDA versions consistent across your derivations:
get the package set from torch / tf rather than picking a top-level one:

```nix
{ python3Packages, ... }:
let
  torch = python3Packages.torch;
  cudaPackages = torch.passthru.cudaPackages or pkgs.cudaPackages;
in
python3Packages.buildPythonPackage {
  …
  buildInputs = [ cudaPackages.cudatoolkit cudaPackages.cudnn ];
}
```

This stops you from accidentally compiling an extension against CUDA 12
when torch was built against CUDA 11.

## Closure auditing

Mismatched CUDA versions are the #1 source of segfaults. To verify:

```bash
nix-tree result | grep -i cuda
# or
nix path-info -rsSh ./result | grep -i cuda
```

You want one cuda toolkit, one cudnn, one nccl. If you see two of any of
those, something pulled a wheel in.

## When you actually want a wheel

Genuine reasons (rare):

- Pure-Python `py3-none-any` wrapper that just *imports* a CUDA-bearing
  package — the wrapper itself has no CUDA code. Then `format = "wheel"`
  is fine; the underlying CUDA package must still be source-built.
- A driver-side helper that only depends on `nvidia-pyindex` style
  marker packages and produces no compiled output.

In every other case: build from source.

## Diagnostic snippets

```python
# What CUDA does PyTorch think it has?
import torch
print(torch.version.cuda)              # toolkit version
print(torch.backends.cudnn.version())  # cudnn version
print(torch.cuda.get_arch_list())      # the SM list it compiled for
print(torch.cuda.get_device_capability(0))   # current device's SM
```

If `get_device_capability(0)` is not in `get_arch_list()`, you'll get
"no kernel image" on the first kernel launch. Fix:
`TORCH_CUDA_ARCH_LIST` or rebuild torch with the wider list.
