<!--
# COMMIT-TRACKING: UUID-20240730-100000-B4D1
# Description: Update Dockerfile links after consolidation, add header.
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 01-cuda/             <- CUDA directory
# │   │       └── cuda/            <- Current directory
# │   │           └── README.md    <- THIS FILE
# └── ...                        <- Other project files
-->
# cuda

> [`CONTAINERS`](#user-content-containers) [`IMAGES`](#user-content-images) [`RUN`](#user-content-run) [`BUILD`](#user-content-build)

<details open>
<summary><b><a id="containers">CONTAINERS</a></b></summary>
<br>

| **`cuda:12.2`** | |
| :-- | :-- |
| &nbsp;&nbsp;&nbsp;Builds | [![`cuda-122_jp60`](https://img.shields.io/github/actions/workflow/status/dusty-nv/jetson-containers/cuda-122_jp60.yml?label=cuda-122:jp60)](https://github.com/dusty-nv/jetson-containers/actions/workflows/cuda-122_jp60.yml) |
| &nbsp;&nbsp;&nbsp;Requires | `L4T ['==35.*']` |
| &nbsp;&nbsp;&nbsp;Dependencies | [`build-essential`](/packages/build/build-essential) [`pip_cache:cu122`](/packages/cuda/cuda) |
| &nbsp;&nbsp;&nbsp;Dependants | [`cuda:12.2-samples`](/packages/cuda/cuda) [`cudnn:8.9`](/packages/cuda/cudnn) [`tensorrt:8.6`](/packages/tensorrt) |
| &nbsp;&nbsp;&nbsp;Dockerfile | [`Dockerfile`](Dockerfile) |
| &nbsp;&nbsp;&nbsp;Images | [`dustynv/cuda:12.2-r36.2.0`](https://hub.docker.com/r/dustynv/cuda/tags) `(2023-12-05, 3.4GB)`<br>[`dustynv/cuda:12.2-samples-r36.2.0`](https://hub.docker.com/r/dustynv/cuda/tags) `(2023-12-07, 4.8GB)` |

| **`cuda:12.4`** | |
| :-- | :-- |
| &nbsp;&nbsp;&nbsp;Requires | `L4T ['==36.*']` |
| &nbsp;&nbsp;&nbsp;Dependencies | [`build-essential`](/packages/build/build-essential) [`pip_cache:cu124`](/packages/cuda/cuda) |
| &nbsp;&nbsp;&nbsp;Dependants | [`cuda:12.4-samples`](/packages/cuda/cuda) [`cudnn:9.0`](/packages/cuda/cudnn) [`tensorrt:10.0`](/packages/tensorrt) |
| &nbsp;&nbsp;&nbsp;Dockerfile | [`Dockerfile`](Dockerfile) |

| **`cuda:12.2-samples`** | |
| :-- | :-- |
| &nbsp;&nbsp;&nbsp;Builds | [![`cuda-122-samples_jp60`](https://img.shields.io/github/actions/workflow/status/dusty-nv/jetson-containers/cuda-122-samples_jp60.yml?label=cuda-122-samples:jp60)](https://github.com/dusty-nv/jetson-containers/actions/workflows/cuda-122-samples_jp60.yml) |
| &nbsp;&nbsp;&nbsp;Requires | `L4T ['==35.*']` |
| &nbsp;&nbsp;&nbsp;Dependencies | [`cuda:12.2`](/packages/cuda/cuda) [`cmake`](/packages/build/cmake/cmake_pip) |
| &nbsp;&nbsp;&nbsp;Dockerfile | [`Dockerfile`](Dockerfile) |
| &nbsp;&nbsp;&nbsp;Images | [`dustynv/cuda:12.2-samples-r36.2.0`](https://hub.docker.com/r/dustynv/cuda/tags) `(2023-12-07, 4.8GB)` |
| &nbsp;&nbsp;&nbsp;Notes | CUDA samples from https://github.com/NVIDIA/cuda-samples installed under /opt/cuda-samples |

| **`cuda:12.4-samples`** | |
| :-- | :-- |
| &nbsp;&nbsp;&nbsp;Requires | `L4T ['==36.*']` |
| &nbsp;&nbsp;&nbsp;Dependencies | [`cuda:12.4`](/packages/cuda/cuda) [`cmake`](/packages/build/cmake/cmake_pip) |
| &nbsp;&nbsp;&nbsp;Dockerfile | [`Dockerfile`](Dockerfile) |
| &nbsp;&nbsp;&nbsp;Notes | CUDA samples from https://github.com/NVIDIA/cuda-samples installed under /opt/cuda-samples |

| **`cuda:11.8`** | |
| :-- | :-- |
| &nbsp;&nbsp;&nbsp;Requires | `L4T ['==35.*']` |
| &nbsp;&nbsp;&nbsp;Dependencies | [`build-essential`](/packages/build/build-essential) [`pip_cache:cu118`](/packages/cuda/cuda) |
| &nbsp;&nbsp;&nbsp;Dependants | [`cuda:11.8-samples`](/packages/cuda/cuda) |
| &nbsp;&nbsp;&nbsp;Dockerfile | [`Dockerfile`](Dockerfile) |

| **`cuda:11.8-samples`** | |
| :-- | :-- |
| &nbsp;&nbsp;&nbsp;Requires | `L4T ['==35.*']` |
| &nbsp;&nbsp;&nbsp;Dependencies | [`cuda:11.8`](/packages/cuda/cuda) [`cmake`](/packages/build/cmake/cmake_pip) |
| &nbsp;&nbsp;&nbsp;Dockerfile | [`Dockerfile`](Dockerfile) |
| &nbsp;&nbsp;&nbsp;Notes | CUDA samples from https://github.com/NVIDIA/cuda-samples installed under /opt/cuda-samples |

| **`cuda:11.4`** | |
| :-- | :-- |
| &nbsp;&nbsp;&nbsp;Aliases | `cuda` |
| &nbsp;&nbsp;&nbsp;Requires | `L4T ['<36']` |
| &nbsp;&nbsp;&nbsp;Dependencies | [`build-essential`](/packages/build/build-essential) [`pip_cache:cu114`](/packages/cuda/cuda) |
| &nbsp;&nbsp;&nbsp;Dependants | *...(existing list)...* |
| &nbsp;&nbsp;&nbsp;Dockerfile | [`Dockerfile`](Dockerfile) |

| **`cuda:11.4-samples`** | |
| :-- | :-- |
| &nbsp;&nbsp;&nbsp;Aliases | `cuda:samples` |
| &nbsp;&nbsp;&nbsp;Requires | `L4T ['<36']` |
| &nbsp;&nbsp;&nbsp;Dependencies | [`cuda:11.4`](/packages/cuda/cuda) [`cmake`](/packages/build/cmake/cmake_pip) |
| &nbsp;&nbsp;&nbsp;Dockerfile | [`Dockerfile`](Dockerfile) |
| &nbsp;&nbsp;&nbsp;Notes | CUDA samples from https://github.com/NVIDIA/cuda-samples installed under /opt/cuda-samples |

<!-- Add entries for pip_cache containers if desired, or rely on config.py -->
| **`pip_cache:cu124`** | |
| :-- | :-- |
| &nbsp;&nbsp;&nbsp;Aliases | `pip_cache` (if CUDA_VERSION=12.4) |
| &nbsp;&nbsp;&nbsp;Requires | `L4T ['==36.*']` (example) |
| &nbsp;&nbsp;&nbsp;Dependencies | - |
| &nbsp;&nbsp;&nbsp;Dockerfile | [`Dockerfile`](Dockerfile) |
| &nbsp;&nbsp;&nbsp;Notes | Sets up pip cache environment variables |

<!-- Repeat for other pip_cache versions as needed -->

</details>

<details open>
<summary><b><a id="images">CONTAINER IMAGES</a></b></summary>
<br>

| Repository/Tag | Date | Arch | Size |
| :-- | :--: | :--: | :--: |
| &nbsp;&nbsp;[`dustynv/cuda:12.2-r36.2.0`](https://hub.docker.com/r/dustynv/cuda/tags) | `2023-12-05` | `arm64` | `3.4GB` |
| &nbsp;&nbsp;[`dustynv/cuda:12.2-samples-r36.2.0`](https://hub.docker.com/r/dustynv/cuda/tags) | `2023-12-07` | `arm64` | `4.8GB` |

> <sub>Container images are compatible with other minor versions of JetPack/L4T:</sub><br>
> <sub>&nbsp;&nbsp;&nbsp;&nbsp;• L4T R32.7 containers can run on other versions of L4T R32.7 (JetPack 4.6+)</sub><br>
> <sub>&nbsp;&nbsp;&nbsp;&nbsp;• L4T R35.x containers can run on other versions of L4T R35.x (JetPack 5.1+)</sub><br>
</details>

<details open>
<summary><b><a id="run">RUN CONTAINER</a></b></summary>
<br>

To start the container, you can use [`jetson-containers run`](/docs/run.md) and [`autotag`](/docs/run.md#autotag), or manually put together a [`docker run`](https://docs.docker.com/engine/reference/commandline/run/) command:
```bash
# automatically pull or build a compatible container image
jetson-containers run $(autotag cuda)

# or explicitly specify one of the container images above
jetson-containers run dustynv/cuda:12.2-samples-r36.2.0

# or if using 'docker run' (specify image and mounts/ect)
sudo docker run --runtime nvidia -it --rm --network=host dustynv/cuda:12.2-samples-r36.2.0
```
> <sup>[`jetson-containers run`](/docs/run.md) forwards arguments to [`docker run`](https://docs.docker.com/engine/reference/commandline/run/) with some defaults added (like `--runtime nvidia`, mounts a `/data` cache, and detects devices)</sup><br>
> <sup>[`autotag`](/docs/run.md#autotag) finds a container image that's compatible with your version of JetPack/L4T - either locally, pulled from a registry, or by building it.</sup>

To mount your own directories into the container, use the [`-v`](https://docs.docker.com/engine/reference/commandline/run/#volume) or [`--volume`](https://docs.docker.com/engine/reference/commandline/run/#volume) flags:
```bash
jetson-containers run -v /path/on/host:/path/in/container $(autotag cuda)
```
To launch the container running a command, as opposed to an interactive shell:
```bash
jetson-containers run $(autotag cuda) my_app --abc xyz
```
You can pass any options to it that you would to [`docker run`](https://docs.docker.com/engine/reference/commandline/run/), and it'll print out the full command that it constructs before executing it.
</details>
<details open>
<summary><b><a id="build">BUILD CONTAINER</b></summary>
<br>

If you use [`autotag`](/docs/run.md#autotag) as shown above, it'll ask to build the container for you if needed.  To manually build it, first do the [system setup](/docs/setup.md), then run:
```bash
jetson-containers build cuda
```
The dependencies from above will be built into the container, and it'll be tested during.  Run it with [`--help`](/jetson_containers/build.py) for build options.
</details>
