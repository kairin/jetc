# --- Footer ---
# File location diagram:
# jetc/                          <- Main project folder
# ├── buildx/                    <- Buildx directory
# │   ├── build/                 <- Build stages directory
# │   │   └── 01-04-cuda/        <- Parent directory
# │   │       └── 001-cuda/      <- Current directory
# │   │           └── config.py  <- THIS FILE
# └── ...                        <- Other project files
#
# Description: Configuration script for the unified CUDA build stage.
# Author: Mr K / GitHub Copilot
# COMMIT-TRACKING: UUID-20250425-080000-42595D

import os
try:
    from packaging.version import Version
except ImportError:
    import subprocess
    import sys
    print("Installing missing 'packaging' module...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "packaging"])
    from packaging.version import Version

from jetson_containers import (
    L4T_VERSION, JETPACK_VERSION, CUDA_VERSION,
    CUDA_ARCHITECTURES, LSB_RELEASE, IS_SBSA, IS_TEGRA,
    SYSTEM_ARM, DOCKER_ARCH, package_requires
)


def cuda_build_args(version):
    """
    Return some common environment settings used between variants of the CUDA containers.
    """
    return {
        'CUDA_ARCH_LIST': ';'.join([str(x) for x in CUDA_ARCHITECTURES]),
        'DISTRO': f"ubuntu{LSB_RELEASE.replace('.','')}",
    }


def cuda_package(version, url, deb=None, packages=None, requires=None) -> list:
    """
    Generate containers for a particular version of CUDA installed from debian packages
    """
    if not deb:
        deb = url.split('/')[-1].split('_')[0]

    if not packages:
        packages = os.environ.get('CUDA_PACKAGES', 'cuda-toolkit*')

    cuda = package.copy()

    cuda['name'] = f'cuda:{version}'
    cuda['dockerfile'] = 'Dockerfile' # Point to unified Dockerfile

    cuda['build_args'] = {
        'INSTALL_MODE': 'package', # Specify mode
        'CUDA_URL': url,
        'CUDA_DEB': deb,
        'CUDA_PACKAGES': packages,
        **cuda_build_args(version)
    }

    if requires:
        cuda['requires'] = requires

    package_requires(cuda, system_arch='aarch64') # default to aarch64

    if 'toolkit' in packages or 'dev' in packages:
        cuda['depends'] = ['build-essential']

    if Version(version) == CUDA_VERSION:
        cuda['alias'] = 'cuda'

    cuda_pip = pip_cache(version, requires)
    cuda['depends'].append(cuda_pip['name'])

    return cuda, cuda_pip


def cuda_builtin(version, requires=None) -> list:
    """
    Backwards-compatability for when CUDA already installed in base container (like l4t-jetpack)
    """
    passthrough = package.copy()

    if not isinstance(version, str):
        version = f'{version.major}.{version.minor}'

    passthrough['name'] = f'cuda:{version}'
    passthrough['dockerfile'] = 'Dockerfile' # Point to unified Dockerfile
    passthrough['build_args'] = {
        'INSTALL_MODE': 'builtin', # Specify mode
        **cuda_build_args(version)
    }

    if Version(version) == CUDA_VERSION:
        passthrough['alias'] = 'cuda'

    if requires:
        passthrough['requires'] = requires

    passthrough['depends'] = ['build-essential']

    cuda_pip = pip_cache(version, requires)
    passthrough['depends'].append(cuda_pip['name'])

    return passthrough, cuda_pip


def cuda_samples(version, requires, branch=None) -> list:
    """
    Generates container that installs/builds the CUDA samples
    """
    samples = package.copy()

    if not isinstance(version, str):
        version = f'{version.major}.{version.minor}'

    samples['name'] = f'cuda:{version}-samples'
    samples['dockerfile'] = 'Dockerfile' # Point to unified Dockerfile
    samples['notes'] = "CUDA samples from https://github.com/NVIDIA/cuda-samples installed under /opt/cuda-samples"
    samples['depends'] = [f'cuda:{version}', 'cmake']

    if not branch:
        branch = 'v' + version

    if Version(version) > Version('12.5'):
        make_cmd='cmake'
        samples['depends'] += ['opengl', 'vulkan']
    elif Version(version) >= Version('12.0'):
        make_cmd='make'
    else:
        make_cmd='make_flat'

    samples['build_args'] = {
        'INSTALL_MODE': 'samples', # Specify mode
        'CUDA_BRANCH': branch,
        'CUDA_SAMPLES_MAKE': make_cmd
    }

    if Version(version) == CUDA_VERSION:
        samples['alias'] = 'cuda:samples'

    if requires:
        samples['requires'] = requires

    return samples


def pip_cache(version, requires=None):
    """
    Defines a container that just sets the environment for using the pip caching server.
    https://github.com/dusty-nv/jetson-containers/blob/master/docs/build.md#pip-server
    """
    short_version = f"cu{version.replace('.', '')}"
    index_host = "jetson-ai-lab.dev"

    pip_path = (
        f"jp{JETPACK_VERSION.major}/{short_version}" if IS_TEGRA
        else f"sbsa/{short_version}" if IS_SBSA
        else f"{DOCKER_ARCH}/{short_version}"
    )

    apt_path = pip_path if Version(LSB_RELEASE).major < 24 else f"{pip_path}/{LSB_RELEASE}"

    pip_cache = package.copy()

    pip_cache['name'] = f'pip_cache:{short_version}'
    pip_cache['group'] = 'build'
    pip_cache['dockerfile'] = 'Dockerfile' # Point to unified Dockerfile
    pip_cache['depends'] = []

    pip_cache['build_args'] = {
        'INSTALL_MODE': 'pip', # Specify mode
        'TAR_INDEX_URL': f"https://apt.{index_host}/{apt_path}",
        'PIP_INDEX_REPO': f"https://pypi.{index_host}/{pip_path}",
        #'PIP_TRUSTED_HOSTS': index_host,
        'PIP_UPLOAD_REPO': os.environ.get('PIP_UPLOAD_REPO', f"{os.environ.get('PIP_UPLOAD_HOST', 'http://localhost')}/{pip_path}"),
        'PIP_UPLOAD_USER': os.environ.get('PIP_UPLOAD_USER', f"jp{JETPACK_VERSION.major}" if SYSTEM_ARM else 'amd64'),
        'PIP_UPLOAD_PASS': os.environ.get('PIP_UPLOAD_PASS', 'none'),
        'SCP_UPLOAD_URL': os.environ.get('SCP_UPLOAD_URL', f"{os.environ.get('SCP_UPLOAD_HOST', 'localhost:/dist')}/{apt_path}"),
        'SCP_UPLOAD_USER': os.environ.get('SCP_UPLOAD_USER'),
        'SCP_UPLOAD_PASS': os.environ.get('SCP_UPLOAD_PASS'),
    }

    if requires:
        pip_cache['requires'] = requires

    if Version(version) == CUDA_VERSION:
        pip_cache['alias'] = 'pip_cache'

    return pip_cache

# --- Platform-Specific CUDA Configurations ---

# Define CUDA versions and their parameters in data structures
# Each entry: (version, url, deb_name, requires, samples_branch_override=None)
cuda_configs_tegra_jp6 = [
    ('12.2', 'https://nvidia.box.com/shared/static/uvqtun1sc0bq76egarc8wwuh6c23e76e.deb', 'cuda-tegra-repo-ubuntu2204-12-2-local', '==36.*'),
    ('12.4', 'https://developer.download.nvidia.com/compute/cuda/12.4.1/local_installers/cuda-tegra-repo-ubuntu2204-12-4-local_12.4.1-1_arm64.deb', None, '==36.*'),
    ('12.6', 'https://developer.download.nvidia.com/compute/cuda/12.6.3/local_installers/cuda-tegra-repo-ubuntu2204-12-6-local_12.6.3-1_arm64.deb', None, '==36.*', '12.5'), # Samples branch override
    ('12.8', 'https://developer.download.nvidia.com/compute/cuda/12.8.1/local_installers/cuda-tegra-repo-ubuntu2204-12-8-local_12.8.1-1_arm64.deb', None, '==36.*'),
    # ('13.0', 'https://developer.download.nvidia.com/compute/cuda/13.0.0/local_installers/cuda-tegra-repo-ubuntu2204-13-0-local_13.0.0-1_arm64.deb', None, '==36.*'),
]

cuda_configs_tegra_jp5 = [
    ('12.2', 'https://developer.download.nvidia.com/compute/cuda/12.2.2/local_installers/cuda-tegra-repo-ubuntu2004-12-2-local_12.2.2-1_arm64.deb', None, '==35.*'),
    ('11.8', 'https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda-tegra-repo-ubuntu2004-11-8-local_11.8.0-1_arm64.deb', None, '==35.*'),
]

cuda_configs_sbsa = [
    ('12.8','https://developer.download.nvidia.com/compute/cuda/12.8.1/local_installers/cuda-repo-ubuntu2404-12-8-local_12.8.1-570.124.06-1_arm64.deb', None, 'aarch64'),
    # ('13.0','https://developer.download.nvidia.com/compute/cuda/13.0.0/local_installers/cuda-repo-ubuntu2404-12-3-local_13.0.0-570.124.06-1_arm64.deb', None, 'aarch64'),
]

cuda_configs_x86_64 = [
    ('12.8', 'https://developer.download.nvidia.com/compute/cuda/12.8.1/local_installers/cuda-repo-ubuntu2404-12-8-local_12.8.1-570.124.06-1_amd64.deb', None, 'x86_64'),
    # ('13.0', 'https://developer.download.nvidia.com/compute/cuda/13.0.0/local_installers/cuda-repo-ubuntu2404-13-0-local_13.0.0-570.124.06-1_amd64.deb', None, 'x86_64'),
]

# --- Generate Package List ---
package = []

# Helper to add package definitions, avoiding duplicates for pip_cache
defined_pip_caches = set()
def add_package_pair(pkg_def, pip_def):
    global package
    package.append(pkg_def)
    if pip_def['name'] not in defined_pip_caches:
        package.append(pip_def)
        defined_pip_caches.add(pip_def['name'])

if IS_TEGRA:
    # JetPack 6
    for config in cuda_configs_tegra_jp6:
        version, url, deb, req, *rest = config
        samples_branch = rest[0] if rest else None
        pkg_def, pip_def = cuda_package(version, url, deb=deb, requires=req)
        add_package_pair(pkg_def, pip_def)
        package.append(cuda_samples(version, requires=req, branch=samples_branch))

    # JetPack 5
    for config in cuda_configs_tegra_jp5:
        version, url, deb, req, *rest = config
        samples_branch = rest[0] if rest else None
        pkg_def, pip_def = cuda_package(version, url, deb=deb, requires=req)
        add_package_pair(pkg_def, pip_def)
        package.append(cuda_samples(version, requires=req, branch=samples_branch))

    # JetPack 4-5 (CUDA installed in base container) - Use cuda_builtin
    pkg_def, pip_def = cuda_builtin(CUDA_VERSION, requires='<36')
    add_package_pair(pkg_def, pip_def)
    package.append(cuda_samples(CUDA_VERSION, requires='<36'))

elif IS_SBSA:
    # SBSA
    for config in cuda_configs_sbsa:
        version, url, deb, req, *rest = config
        samples_branch = rest[0] if rest else None
        pkg_def, pip_def = cuda_package(version, url, deb=deb, requires=req)
        add_package_pair(pkg_def, pip_def)
        package.append(cuda_samples(version, requires=req, branch=samples_branch))

else:
    # x86_64
    for config in cuda_configs_x86_64:
        version, url, deb, req, *rest = config
        samples_branch = rest[0] if rest else None
        pkg_def, pip_def = cuda_package(version, url, deb=deb, requires=req)
        add_package_pair(pkg_def, pip_def)
        package.append(cuda_samples(version, requires=req, branch=samples_branch))
