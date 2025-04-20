<!--
# COMMIT-TRACKING: UUID-20240731-093001-PLATALL
# Description: Clarify build-time test scope (CPU only).
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-01-numba/         <- Current directory
# │   │       └── README.md        <- THIS FILE
# └── ...                        <- Other project files
-->
# numba

> [`CONTAINERS`](#user-content-containers) [`IMAGES`](#user-content-images) [`RUN`](#user-content-run) [`BUILD`](#user-content-build)

<details open>
<summary><b><a id="containers">CONTAINERS</a></b></summary>
<br>

| **`numba`** | |
| :-- | :-- |
| &nbsp;&nbsp;&nbsp;Builds | *Build status badges removed as they pointed to an external project.* |
| &nbsp;&nbsp;&nbsp;Requires | `L4T ['>=32.6']` (Adjust based on your target L4T versions) |
| &nbsp;&nbsp;&nbsp;Dependencies | [`cuda`](../00-base/01-cuda) [`numpy`](../01-00-numpy) |
| &nbsp;&nbsp;&nbsp;Dependants | *Update with packages within this project that depend on numba* |
| &nbsp;&nbsp;&nbsp;Dockerfile | [`Dockerfile`](Dockerfile) |
| &nbsp;&nbsp;&nbsp;Images | *See image details below* |
| &nbsp;&nbsp;&nbsp;Notes | The build-time test verifies Numba's CPU JIT functionality. CUDA features require the appropriate base image and runtime environment (`--runtime nvidia`). |

</details>

<details open>
<summary><b><a id="images">CONTAINER IMAGES</a></b></summary>
<br>

<!-- This section should list images built by *your* build process -->
<!-- Example format: | Repository/Tag | Date | Arch | Size | -->
<!--                 | :-- | :--: | :--: | :--: | -->
<!--                 | &nbsp;&nbsp;`your-repo/001:01-01-numba-tag` | `YYYY-MM-DD` | `arm64` | `X.YGB` | -->

This container is built locally by the `build.sh` script. Refer to the script's output or your local Docker image list (`docker images`) for the exact image tag (e.g., `your_username/001:01-01-numba`).

> <sub>Container images are compatible with other minor versions of JetPack/L4T:</sub><br>
> <sub>&nbsp;&nbsp;&nbsp;&nbsp;• L4T R32.7 containers can run on other versions of L4T R32.7 (JetPack 4.6+)</sub><br>
> <sub>&nbsp;&nbsp;&nbsp;&nbsp;• L4T R35.x containers can run on other versions of L4T R35.x (JetPack 5.1+)</sub><br>
> <sub>&nbsp;&nbsp;&nbsp;&nbsp;• L4T R36.x containers can run on other versions of L4T R36.x (JetPack 6.0+)</sub><br>
</details>

<details open>
<summary><b><a id="run">RUN CONTAINER</a></b></summary>
<br>

To start the container built by your script, use a [`docker run`](https://docs.docker.com/engine/reference/commandline/run/) command:
```bash
# Replace 'your_username/001:01-01-numba' with the actual tag built by your script
sudo docker run --runtime nvidia -it --rm --network=host your_username/001:01-01-numba
```
> <sup>The `--runtime nvidia` flag enables GPU access. Mounts and other options can be added as needed.</sup>

To mount your own directories into the container, use the [`-v`](https://docs.docker.com/engine/reference/commandline/run/#volume) or [`--volume`](https://docs.docker.com/engine/reference/commandline/run/#volume) flags:
```bash
# Replace 'your_username/001:01-01-numba' with the actual tag built by your script
sudo docker run --runtime nvidia -it --rm --network=host -v /path/on/host:/path/in/container your_username/001:01-01-numba
```
To launch the container running a command, as opposed to an interactive shell:
```bash
# Replace 'your_username/001:01-01-numba' with the actual tag built by your script
sudo docker run --runtime nvidia -it --rm --network=host your_username/001:01-01-numba my_app --abc xyz
```
</details>
<details open>
<summary><b><a id="build">BUILD CONTAINER</b></summary>
<br>

To build this container using your script:
```bash
# Navigate to the buildx directory
cd /media/kkk/Apps/jetc/buildx 

# Run the build script (it should handle building this stage based on its name)
./build.sh 
```
The dependencies from above will be built into the container, and it'll be tested during the build process.
</details>
