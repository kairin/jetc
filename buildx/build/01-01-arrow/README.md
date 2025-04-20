## Build Summary (Initial Attempt)

**Build Parameters:**
*   Image Name: 01-01-arrow
*   Platform: linux/arm64
*   Tag: kairin/001:01-01-arrow
*   Base Image: kairin/001:01-00-build-essential
*   Arrow Branch: apache-arrow-16.1.0

**Error Encountered:**
The build failed during the CMake configuration step for Arrow's C++ components.

```
 => ERROR [3/8] RUN cd /opt/arrow/cpp &&     mkdir build &&     cd build &&     cmake       -DCMAKE_INSTALL_PREFIX=/usr/local ... -DARROW_ORC=ON ... ../ && make -j$(nproc) && make install
------
 > [3/8] RUN cd /opt/arrow/cpp && ... cmake ... && make -j$(nproc) && make install:
... (CMake configuration output) ...
5.033 CMake Error at /usr/local/lib/python3.12/dist-packages/cmake/data/share/cmake-3.31/Modules/ExternalProject.cmake:1816 (file):
5.033   Error evaluating generator expression:
5.033
5.033     $<TARGET_FILE:protobuf::libprotoc>
5.033
5.033   No target "protobuf::libprotoc"
... (Call Stack) ...
5.247 CMake Generate step failed.  Build files cannot be regenerated correctly.
------
ERROR: failed to solve: process "/bin/sh -c cd /opt/arrow/cpp && ... cmake ... && make -j$(nproc) && make install" did not complete successfully: exit code: 1
```

## Build Notes

### Protobuf Build Issue (Resolved)

**Problem:**
During the CMake configuration step for Arrow, the build failed with an error similar to:
```
CMake Error ... No target "protobuf::libprotoc"
```
This happened specifically when the ORC component (`-DARROW_ORC=ON`) was being configured.

**Cause:**
The Arrow build system needs the Protocol Buffers compiler (`protoc`) and libraries. We initially installed the system versions (`libprotobuf-dev`, `protobuf-compiler`) using `apt-get`. However, the Arrow build system (especially for sub-components like ORC) sometimes has specific expectations about the Protobuf version or its CMake configuration, leading to a conflict with the system-installed version. CMake found the system `protoc` executable but couldn't find the specific CMake target (`protobuf::libprotoc`) it needed.

**Solution:**
To resolve this, we forced the Arrow build system to use its own bundled version of Protobuf instead of relying on the potentially incompatible system version. This was done in two parts within the `Dockerfile`:

1.  **Remove System Protobuf:** Right before running the `cmake` command for Arrow, we removed the system Protobuf development packages:
    ```dockerfile
    RUN apt-get update && \
        # ... install dependencies including libprotobuf-dev, protobuf-compiler ...
        apt-get remove -y libprotobuf-dev protobuf-compiler && \
        apt-get autoremove -y --purge && \
        # ... rest of the build command ...
    ```
2.  **Specify Bundled Source:** We explicitly told CMake to use the Protobuf source code included within the Arrow source tree by adding the following flag to the `cmake` command:
    ```cmake
    -DProtobuf_SOURCE=BUNDLED
    ```

These changes ensure that Arrow builds and uses a consistent version of Protobuf, avoiding conflicts with system packages and resolving the build error.
