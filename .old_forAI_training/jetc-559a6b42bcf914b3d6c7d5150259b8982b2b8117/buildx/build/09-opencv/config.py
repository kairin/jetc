from jetson_containers import CUDA_VERSION, CUDA_ARCHITECTURES
from packaging.version import Version

def opencv(version, requires=None, default=False, url=None):
    cv = package.copy()
    pkg_name = f'opencv:{version}'
    
    # Common build args
    cv_build_args = {
        'OPENCV_VERSION': version,
        'OPENCV_PYTHON': f"{version.split('.')[0]}.x",
        'CUDA_ARCH_BIN': ','.join([f'{x/10:.1f}' for x in CUDA_ARCHITECTURES]),
    }

    # Runtime package configuration
    cv['name'] = pkg_name
    cv['dockerfile'] = 'Dockerfile.runtime' # Use the runtime Dockerfile
    cv['build_args'] = cv_build_args.copy()

    if url:
        cv['build_args']['OPENCV_URL'] = url
        cv['name'] = f'{pkg_name}-deb' # Distinguish deb package name
        if default:
             cv['alias'] = cv.get('alias', []) + ['opencv', 'opencv:deb'] # Add default alias for deb
    else:
        # This is the pip-based runtime package
        if default:
            cv['alias'] = cv.get('alias', []) + ['opencv'] # Add default alias for pip

    if requires:
        cv['requires'] = requires

    # Builder package configuration
    builder = cv.copy() # Start from runtime config
    builder['name'] = f'{pkg_name}-builder'
    builder['dockerfile'] = 'Dockerfile.builder' # Use the builder Dockerfile
    # Builder inherits common args, no need for OPENCV_URL
    builder['build_args'] = cv_build_args.copy()
    # Remove alias from builder if copied
    builder.pop('alias', None) 
    if default:
         builder['alias'] = 'opencv:builder' # Add specific builder alias if default

    # Return based on whether it's a deb package (URL provided) or pip package
    if url:
        # For deb packages, we typically only define the runtime installer
        # The builder isn't strictly necessary unless you want to rebuild the deb
        # Let's return only the runtime 'cv' for deb for simplicity now.
        # If rebuilding debs is needed, the builder can be returned too.
        return cv 
    else:
        # For pip packages, return both runtime installer and the builder
        return cv, builder

package = [
    # JetPack 5/6 (Pip based)
    *opencv('4.8.1', '>=35', default=(CUDA_VERSION <= Version('12.2'))),
    *opencv('4.10.0', '>=35', default=(CUDA_VERSION >= Version('12.4') and CUDA_VERSION <= Version('12.6'))),
    *opencv('4.11.0', '>=35', default=(CUDA_VERSION > Version('12.6'))),

    # JetPack 4 (Deb based)
    opencv('4.5.0', '==32.*', default=True, url='https://nvidia.box.com/shared/static/5v89u6g5rb62fpz4lh0rz531ajo2t5ef.gz'),
    
    # Optional Debians for JP5/6 (C++ focus) - uncomment if needed
    # opencv('4.5.0', '==35.*', default=False, url='https://nvidia.box.com/shared/static/2hssa5g3v28ozvo3tc3qwxmn78yerca9.gz'),
    # opencv('4.8.1', '==36.*', default=False, url='https://nvidia.box.com/shared/static/ngp26xb9hb7dqbu6pbs7cs9flztmqwg0.gz'),
]

# Flatten the list in case opencv function returns multiple items
package = [item for sublist in package for item in (sublist if isinstance(sublist, tuple) else [sublist])]
