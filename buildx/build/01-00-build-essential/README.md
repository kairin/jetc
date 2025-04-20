```log
Initial base image set to: kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu
Determining build order...
Starting build process...
--- Building Numbered Directories ---
Processing numbered directory: build/01-00-build-essential
Using base image: kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu
--------------------------------------------------
Building image from folder: build/01-00-build-essential
Image Name: 01-00-build-essential
Platform: linux/arm64
Tag: kairin/001:01-00-build-essential
Base Image (FROM via ARG): kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu
Skip Intermediate Push/Pull: n
--------------------------------------------------
Using --no-cache
Using --push
Running: docker buildx build --platform linux/arm64 -t kairin/001:01-00-build-essential --build-arg BASE_IMAGE=kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu --no-cache --push build/01-00-build-essential
[+] Building 20.6s (12/12) FINISHED                                                                   docker-container:jetson-builder
 => [internal] load build definition from Dockerfile                                                                             0.0s
 => => transferring dockerfile: 7.82kB                                                                                           0.0s
 => WARN: RedundantTargetPlatform: Setting platform to predefined $TARGETPLATFORM in FROM is redundant as this is the default b  0.0s
 => [internal] load metadata for docker.io/kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu                                         1.8s
 => [auth] kairin/001:pull token for registry-1.docker.io                                                                        0.0s
 => [internal] load .dockerignore                                                                                                0.0s
 => => transferring context: 2B                                                                                                  0.0s
 => CACHED [1/6] FROM docker.io/kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu@sha256:dde556a5bcbffea413d29bca3f0f9c05eb7107c1e6  0.0s
 => => resolve docker.io/kairin/001:jetc-nvidia-pytorch-25.03-py3-igpu@sha256:dde556a5bcbffea413d29bca3f0f9c05eb7107c1e6b57dac0  0.0s
 => [2/6] RUN touch /opt/list_app_checks.sh                                                                                      0.1s
 => [3/6] RUN set -ex     && apt-get update     && apt-get install -y --no-install-recommends         locales         locales-  10.5s
 => [4/6] RUN echo '#!/usr/bin/env bash' > /tmp/vercmp &&     echo '#' >> /tmp/vercmp &&     echo '# Backportable version compa  0.1s
 => [5/6] RUN echo '#!/usr/bin/env bash' > /tmp/tarpack &&     echo 'set -ex' >> /tmp/tarpack &&     echo '' >> /tmp/tarpack &&  0.1s
 => [6/6] RUN echo "# Check for build tools" >> /tmp/build_checks.sh     && echo "check_cmd gcc 'gcc --version'" >> /tmp/build_  0.2s
 => exporting to image                                                                                                           7.5s
 => => exporting layers                                                                                                          0.5s
 => => exporting manifest sha256:b559fd52c0e99ea4f2412fdc8f406ef357a1070ec29d22e04912bbc830243aaf                                0.0s
 => => exporting config sha256:2082fc9135a9251a530e7cd54076245122ef791ecda90c609ef8eb35638a6aee                                  0.0s
 => => exporting attestation manifest sha256:ae9e10ff5108aa45ceb0d1e88b06f24a16ee56e641ff807e909a6bd0001544fb                    0.0s
 => => exporting manifest list sha256:aafe9bc88238dabfe9d5592079a38aec110d51a052e981cdfb225eb0cd5c7717                           0.0s
 => => pushing layers                                                                                                            4.3s
 => => pushing manifest for docker.io/kairin/001:01-00-build-essential@sha256:aafe9bc88238dabfe9d5592079a38aec110d51a052e981cdf  2.7s
 => [auth] kairin/001:pull,push token for registry-1.docker.io                                                                   0.0s
Successfully built image: kairin/001:01-00-build-essential
Pulling image kairin/001:01-00-build-essential to ensure it's available locally...
01-00-build-essential: Pulling from kairin/001
14fcbe0c9272: Already exists
9c92e5240789: Already exists
0de21df19981: Pull complete
6dbc88b20006: Pull complete
34ab0cf6029d: Pull complete
f04e366e1ed2: Pull complete
6c480dbc6889: Pull complete
Digest: sha256:aafe9bc88238dabfe9d5592079a38aec110d51a052e981cdfb225eb0cd5c7717
Status: Downloaded newer image for kairin/001:01-00-build-essential
docker.io/kairin/001:01-00-build-essential
Successfully pulled image kairin/001:01-00-build-essential.
Image kairin/001:01-00-build-essential verified locally after pull.
Successfully built, pushed, and pulled numbered image: kairin/001:01-00-build-essential
Next base image will be: kairin/001:01-00-build-essential
Processing numbered directory: build/01-01-arrow
Using base image: kairin/001:01-00-build-essential
```
