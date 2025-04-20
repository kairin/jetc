Building image from folder: build/01-01-numba
Image Name: 01-01-numba
Platform: linux/arm64
Tag: kairin/001:01-01-numba
Base Image (FROM via ARG): kairin/001:01-00-build-essential
Skip Intermediate Push/Pull: n
--------------------------------------------------
**Build Summary:**

*   **Command:** `docker buildx build --platform linux/arm64 -t kairin/001:01-01-numba --build-arg BASE_IMAGE=kairin/001:01-00-build-essential --no-cache --push build/01-01-numba`
*   **Duration:** 100.5 seconds
*   **Steps:**
    *   Installed `llvm-dev`.
    *   Installed `numba` via pip3.
    *   Ran embedded Numba test script (CPU JIT).
    *   Added Numba dependency checks.
*   **Warning:** Redundant platform setting in `FROM` instruction.
*   **Outcome:** Successfully built, pushed (`docker.io/kairin/001:01-01-numba`), and pulled the image locally for verification.
*   **Next Base Image:** `kairin/001:01-01-numba`
*   **Next Directory:** `build/01-01-numpy`
--------------------------------------------------
