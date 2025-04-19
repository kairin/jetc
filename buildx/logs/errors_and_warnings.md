<!-- COMMIT-TRACKING: UUID-20240730-022937-A1B2 -->
<!-- Description: Summary of errors and warnings from build log log4 -->
<!-- Author: GitHub Copilot -->
<!-- -->
<!-- File location diagram: -->
<!-- jetc/                          <- Main project folder -->
<!-- ├── buildx/                    <- Buildx directory -->
<!-- │   ├── logs/                  <- Logs directory -->
<!-- │   │   ├── log4               <- Input log file -->
<!-- │   │   └── errors_and_warnings.md <- THIS FILE -->
<!-- │   └── ...                    <- Other buildx files -->
<!-- └── ...                        <- Other project files -->

# Errors and Warnings Summary from log4

This document lists the errors and warnings encountered during the build process recorded in `log4`.

## General Script Errors

*   `./scripts/setup_env.sh: line 109: syntax error near unexpected token \`}'`
*   `./scripts/setup_env.sh: line 109: \`    }'`
*   `./build.sh: line 52: get_user_preferences: command not found`

## Docker Build Errors and Warnings

### build/01-00-build-essential
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 26)`

### build/01-01-arrow
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 16)`
*   **Error:** `ERROR [2/8] RUN git clone --branch=${ARROW_BRANCH} ...`
    *   `warning: Could not find remote branch  to clone.`
    *   `fatal: Remote branch  not found in upstream origin`
*   **Error:** `ERROR: failed to solve: process "/bin/sh -c git clone --branch=${ARROW_BRANCH}..." did not complete successfully: exit code: 128`
*   **Error:** `Failed to build image for 01-01-arrow (build/01-01-arrow).`
*   **Error:** `Build process for build/01-01-arrow exited with code 1`

### build/01-01-numba
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 16)`
*   **Error:** `ERROR [4/5] RUN echo '#!/usr/bin/env python3' > /tmp/test_numba.py ...`
    *   `Traceback ... numba.cuda.cudadrv.error.CudaSupportError: Error at driver init: CUDA driver library cannot be found.`
*   **Error:** `ERROR: failed to solve: process "/bin/sh -c echo '#!/usr/bin/env python3' > /tmp/test_numba.py..." did not complete successfully: exit code: 1`
*   **Error:** `Failed to build image for 01-01-numba (build/01-01-numba).`
*   **Error:** `Build process for build/01-01-numba exited with code 1`

### build/01-cuda
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 21)`
*   **Warning:** `WARN: UndefinedVar: Usage of undefined variable '$LD_LIBRARY_PATH' (line 35)`
*   **Error:** `ERROR [2/5] COPY cuda/install.sh /tmp/cuda/install.sh`
*   **Error:** `ERROR: failed to solve: failed to compute cache key: ... "/cuda/install.sh": not found`
*   **Error:** `Failed to build image for 01-cuda (build/01-cuda).`
*   **Error:** `Build process for build/01-cuda exited with code 1`

### build/04-python
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 28)`

### build/05-h5py
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 27)`

### build/06-rust
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 27)`

### build/07-protobuf_apt
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 28)`

### build/08-protobuf_cpp
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 28)`

### build/09-opencv
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 29)`

### build/10-onnx
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 21)`

### build/10-onnxruntime
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 22)`
*   **Error:** `ERROR [3/3] RUN /tmp/onnxruntime/install.sh || /tmp/onnxruntime/build.sh`
    *   `TensorRT NVDLA compiler library not found`
*   **Error:** `ERROR: failed to solve: process "/bin/sh -c /tmp/onnxruntime/install.sh || /tmp/onnxruntime/build.sh" did not complete successfully: exit code: 1`
*   **Error:** `Failed to build image for 10-onnxruntime (build/10-onnxruntime).`
*   **Error:** `Build process for build/10-onnxruntime exited with code 1`

### build/10-triton
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 25)`
*   **Error:** `ERROR [4/4] RUN chmod +x /tmp/triton/build.sh ...`
    *   `ERROR: Invalid requirement: 'triton=='`
    *   `fatal: Remote branch --depth=1 not found in upstream origin`
*   **Error:** `ERROR: failed to solve: process "/bin/sh -c chmod +x /tmp/triton/build.sh..." did not complete successfully: exit code: 128`
*   **Error:** `Failed to build image for 10-triton (build/10-triton).`
*   **Error:** `Build process for build/10-triton exited with code 1`

### build/11-diffusers
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 30)`

### build/12-huggingface_hub
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 28)`

### build/13-transformers
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 18)`

### build/14-xformers
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 30)`

### build/15-flash-attention
*   **Warning:** `WARN: FromPlatformFlagConstDisallowed: FROM --platform flag should not use constant value "linux/arm64" (line 29)`
*   **Error:** Build interrupted by user (`^C`).
*   **Error:** `Failed to build image for 15-flash-attention (build/15-flash-attention).`
*   **Error:** `Build process for build/15-flash-attention exited with code 1`

### build/16-stable-diffusion
*   Build interrupted by user (`^C`) before starting.
