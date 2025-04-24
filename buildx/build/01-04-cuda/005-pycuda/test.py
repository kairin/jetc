#!/usr/bin/env python3

# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Buildx directory
# │   ├── build/                 <- Build stages directory
# │   │   └── 01-04-cuda/        <- Parent directory
# │   │       └── 005-pycuda/    <- Current directory
# │   │           └── test.py    <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Test script for PyCUDA installation.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D


print('Testing PyCUDA...')

import pycuda.driver as drv
import pycuda.autoinit
import numpy as np
from pycuda.compiler import SourceModule

# Print version information
import pycuda
print(f'PyCUDA version: {pycuda.VERSION}')

# Get GPU information
device = pycuda.autoinit.device
print(f'Using device: {device.name()}')
print(f'Compute capability: {device.compute_capability()}')
print(f'Total memory: {device.total_memory() // 1024 // 1024} MB')

# Simple vector addition test
mod = SourceModule("""
__global__ void add(float *a, float *b, float *c)
{
  int i = threadIdx.x;
  c[i] = a[i] + b[i];
}
""")

add_kernel = mod.get_function("add")

a = np.random.randn(32).astype(np.float32)
b = np.random.randn(32).astype(np.float32)
c = np.zeros_like(a)

add_kernel(
    drv.In(a), drv.In(b), drv.Out(c),
    block=(32, 1, 1), grid=(1, 1)
)

print("Vector addition test results:")
print(f"Python result: {a[0]} + {b[0]} = {a[0] + b[0]}")
print(f"CUDA kernel result: {c[0]}")
print(f"Match: {abs(a[0] + b[0] - c[0]) < 1e-6}")

print('PyCUDA test completed successfully!')
