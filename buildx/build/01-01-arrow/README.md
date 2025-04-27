<!-- COMMIT-TRACKING: UUID-20240731-110000-NOORC -->
<!-- Description: Disable ARROW_ORC build option due to configuration errors. -->
<!-- Author: GitHub Copilot -->

# Arrow Dockerfile Optimizations and Fixes

This README documents the changes made to the Dockerfile in this directory.

## Changes Applied (Previous - UUID-20240731-103000-MAKEJ4)

1.  **Reduced Make Parallelism:** Changed `make -j$(nproc)` to `make -j4` during the Arrow C++ build to potentially mitigate resource exhaustion issues and get clearer error messages if the build still fails.
2.  **Updated Commit Tracking:** Updated headers in `Dockerfile`, `config.py`, and this `README.md`.

## Changes Applied (Current - UUID-20240731-110000-NOORC)

1.  **Disabled ORC Build:** Added `-DARROW_ORC=OFF` to the CMake configuration to disable building the ORC component, which was failing during its configuration step.
2.  **Updated Commit Tracking:** Updated headers in `Dockerfile`, `config.py`, and this `README.md`.

These changes disable the problematic ORC component build and ensure consistency in commit tracking.
