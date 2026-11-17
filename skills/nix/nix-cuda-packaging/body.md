# Nix CUDA / GPU packaging

Use this skill when packaging anything that imports `torch`, `tensorflow`,
`jax`, `cupy`, `opencv` with CUDA, or any other GPU-accelerated stack —
or when packaging a custom CUDA C/C++ binary.

## The non-negotiable rule

**Build from source. Never use pre-built wheels.**

Pre-built wheels carry hardcoded CUDA versions, glibc assumptions, and GPU
SM lists baked at build time. Mixing them with the rest of nixpkgs's CUDA
toolchain produces one of:

- `CUDA error: no kernel image is available for execution on the device`
- `cuDNN version mismatch`
- Segfaults the first time the GPU is touched
- `CUDA driver version is insufficient`

The fix is always "build it again from source against the nixpkgs CUDA
toolchain." Every shortcut returns the same failure mode.

In a Python derivation that means: `preferWheel = false;` and **never**
`format = "wheel"` for anything that touches CUDA.

## CUDA C/C++ skeleton

```nix
{ lib, stdenv, fetchFromGitHub, cmake, cudaPackages }:

stdenv.mkDerivation (finalAttrs: {
  pname   = "my-cuda-app";
  version = "1.0.0";
  src     = fetchFromGitHub { /* ... */ };

  nativeBuildInputs = [
    cmake
    cudaPackages.cuda_nvcc        # the nvcc compiler
  ];

  buildInputs = [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    cudaPackages.cublas
    # add as needed: cufft, curand, cusparse, cusolver, cutensor, nccl, …
  ];

  cmakeFlags = [
    "-DCUDA_TOOLKIT_ROOT_DIR=${cudaPackages.cudatoolkit}"
    "-DCUDNN_INCLUDE_DIR=${cudaPackages.cudnn}/include"
    "-DCUDNN_LIBRARY=${cudaPackages.cudnn}/lib/libcudnn.so"
  ];

  preBuild = ''
    export CUDA_HOME="${cudaPackages.cudatoolkit}"
    export CUDNN_HOME="${cudaPackages.cudnn}"
  '';

  meta = {
    description  = "CUDA-accelerated app";
    license      = lib.licenses.mit;
    platforms    = lib.platforms.linux;
    badPlatforms = lib.platforms.darwin;   # CUDA is Linux-only
  };
})
```

## CUDA Python skeleton

@{context7_tip}\`\`\`nix
{ lib, buildPythonPackage, fetchPypi, setuptools, wheel, cudaPackages, torch }:

buildPythonPackage rec {
pname = "my-cuda-pkg";
version = "1.0.0";
pyproject = true;

src = fetchPypi { inherit pname version; hash = "sha256-..."; };

preferWheel = false; # MANDATORY for anything CUDA

build-system = [ setuptools wheel ];

nativeBuildInputs = \[
cudaPackages.cuda_nvcc
\];

buildInputs = \[
cudaPackages.cudatoolkit
cudaPackages.cudnn
\];

dependencies = \[
torch # build-from-source torch, NOT torch-bin
\];

preBuild = ''
export CUDA_HOME="${cudaPackages.cudatoolkit}"
export CUDNN_HOME="${cudaPackages.cudnn}"
export TORCH_CUDA_ARCH_LIST="${torch.cudaCapabilities or "6.0;7.0;7.5;8.0;8.6;8.9;9.0"}"
'';

doCheck = false; # GPU tests need a real GPU
pythonImportsCheck = [ "my_cuda_pkg" ];

meta = {
platforms = lib.platforms.linux;
badPlatforms = lib.platforms.darwin;
};
}

````

Two things make this work:

- **`preferWheel = false;`** — forces sdist + source build, ignoring any
  `manylinux` wheel.
- **`dependencies = [ torch ];`** — pulls in the nixpkgs `torch` built
  against this `cudaPackages`. Never `torch-bin` (which is the wheel
  variant).

## TORCH_CUDA_ARCH_LIST

GPU SM (streaming-multiprocessor) versions to compile kernels for. Wider
list = bigger binary, longer build, more compatible.

| SM | GPU family | Examples |
|----|------------|----------|
| 6.0 | Pascal | P100 |
| 6.1 | Pascal | GTX 1080 / 1070 |
| 7.0 | Volta | V100 |
| 7.5 | Turing | RTX 2080, T4 |
| 8.0 | Ampere | A100 |
| 8.6 | Ampere | RTX 3090, A40 |
| 8.9 | Ada | RTX 4090 |
| 9.0 | Hopper | H100 |

Inherit from the upstream torch package when extending it:

```nix
preBuild = ''
  export TORCH_CUDA_ARCH_LIST="${torch.cudaCapabilities or torch.TORCH_CUDA_ARCH_LIST}"
'';
````

If you know the target hardware exactly (e.g. a Jetson Orin), narrow to a
single arch — much faster builds.

## Common CUDA packages

### CuPy (numpy-on-GPU)

```nix
buildPythonPackage rec {
  pname = "cupy"; pyproject = true;
  preferWheel = false;
  nativeBuildInputs = [ cudaPackages.cuda_nvcc ];
  buildInputs = [
    cudaPackages.cudatoolkit cudaPackages.cublas cudaPackages.cufft
    cudaPackages.curand cudaPackages.cusparse cudaPackages.cusolver
  ];
  preBuild = ''export CUDA_PATH="${cudaPackages.cudatoolkit}"'';
}
```

### OpenCV with CUDA

```nix
stdenv.mkDerivation (finalAttrs: {
  pname = "opencv"; version = "4.x";
  nativeBuildInputs = [ cmake cudaPackages.cuda_nvcc ];
  buildInputs = [ cudaPackages.cudatoolkit cudaPackages.cudnn ];
  cmakeFlags = [
    "-DWITH_CUDA=ON"
    "-DCUDA_TOOLKIT_ROOT_DIR=${cudaPackages.cudatoolkit}"
    "-DCUDA_ARCH_BIN=7.5,8.0,8.6,8.9"
  ];
})
```

For PyTorch extensions, TensorFlow ops, JAX custom-call libraries → see
[references/ml-frameworks.md](references/ml-frameworks.md).

## Verifying at runtime

```bash
nix-shell -p python3Packages.torch --run \
  "python -c 'import torch; print(torch.cuda.is_available(), torch.version.cuda)'"

nix-shell -p python3Packages.torch --run \
  "python -c 'import torch; x=torch.randn(1024,1024).cuda(); print((x@x).sum().item())'"
```

`is_available() == True` is necessary but not sufficient — a matmul on GPU
is the real "does the kernel match this SM" check.

## Diagnosing the usual failures

| Error | Cause | Fix |
|-------|-------|-----|
| `no kernel image is available for execution` | Compiled SM list doesn't include the device's SM | Add the SM to `TORCH_CUDA_ARCH_LIST` |
| `cuDNN version mismatch` | Mixed cuDNN versions — wheel + nixpkgs | Source build everything; verify `cudaPackages.cudnn` is the only cudnn in the closure |
| `CUDA driver version is insufficient` | Host driver older than the toolkit | Update host driver, or downgrade `cudaPackages` |
| Segfault first time CUDA is touched | Almost always a wheel/source mix | Audit closure: `nix-tree result \| grep -i cuda` |
| `nvcc fatal: Unsupported gpu architecture 'compute_90'` | Old nvcc, new SM | Bump `cudaPackages` to a version that knows the SM |

## Don't do this

- `preferWheel = true` on anything CUDA. The wheel will install; it just
  won't work. Source build only.
- `torch-bin` / `tensorflow-bin` as a `dependencies` entry. These exist for
  CPU-only quick installs; they're poison for downstream CUDA packages.
- `format = "wheel"` for `manylinux_*` distributions of CUDA packages.
- Letting `pip install` happen inside a build phase. The result will be a
  glibc/CUDA-mismatched binary at the bottom of your store.

## References

- [references/ml-frameworks.md](references/ml-frameworks.md) — PyTorch
  extensions, TensorFlow ops, JAX custom-call libraries, common nvidia
  closed-source bits (TensorRT, NCCL), arch-list inheritance recipes.
- For overlay-based CUDA-toolkit swaps see `nix-overlays`.
- For non-CUDA Python packaging see `nix-python-packaging`.
- For validation tooling see `nix-quality`.
