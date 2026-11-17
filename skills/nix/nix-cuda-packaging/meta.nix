{
  name = "nix-cuda-packaging";
  description = "Package CUDA / GPU-accelerated software with Nix. CRITICAL: never use pre-built wheels for anything that touches CUDA / PyTorch / TensorFlow / JAX / cupy / OpenCV-CUDA. Always source-build with preferWheel = false. Covers cudaPackages selection, TORCH_CUDA_ARCH_LIST tuning, framework extensions (PyTorch ops / TF ops / JAX custom calls), TensorRT / NCCL, and closure auditing for wheel-vs-source mixups. Use when packaging any GPU code or diagnosing `no kernel image` / `cuDNN mismatch` / segfault-on-first-kernel errors.";
  allowedTools = "Read, Write, Edit, Glob, Grep, Bash, WebFetch, mcp__mcp-pypi__search_packages, mcp__mcp-pypi__get_package_info";
}
