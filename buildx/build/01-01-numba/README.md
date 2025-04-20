Building image from folder: build/01-01-numba
Image Name: 01-01-numba
Platform: linux/arm64
Tag: kairin/001:01-01-numba
Base Image (FROM via ARG): kairin/001:01-00-build-essential
Skip Intermediate Push/Pull: n
--------------------------------------------------
Using --no-cache
Using --push
Running: docker buildx build --platform linux/arm64 -t kairin/001:01-01-numba --build-arg BASE_IMAGE=kairin/001:01-00-build-essential --no-cache --push build/01-01-numba
[+] Building 100.5s (10/10) FINISHED                                                                  docker-container:jetson-builder
 => [internal] load build definition from Dockerfile                                                                             0.0s
 => => transferring dockerfile: 5.59kB                                                                                           0.0s
 => WARN: RedundantTargetPlatform: Setting platform to predefined $TARGETPLATFORM in FROM is redundant as this is the default b  0.0s
 => [internal] load metadata for docker.io/kairin/001:01-00-build-essential                                                      0.3s
 => [internal] load .dockerignore                                                                                                0.0s
 => => transferring context: 2B                                                                                                  0.0s
 => CACHED [1/5] FROM docker.io/kairin/001:01-00-build-essential@sha256:aafe9bc88238dabfe9d5592079a38aec110d51a052e981cdfb225eb  0.0s
 => => resolve docker.io/kairin/001:01-00-build-essential@sha256:aafe9bc88238dabfe9d5592079a38aec110d51a052e981cdfb225eb0cd5c77  0.0s
 => [2/5] RUN apt-get update &&     apt-get install -y --no-install-recommends     llvm-dev     && rm -rf /var/lib/apt/lists/*  30.8s
 => [3/5] RUN pip3 install --no-cache-dir --break-system-packages numba &&     echo "Installed numba version:" &&     pip3 show  3.5s 
 => [4/5] RUN echo '#!/usr/bin/env python3' > /tmp/test_numba.py &&     echo "print('testing numba...')" >> /tmp/test_numba.py   2.6s 
 => [5/5] RUN echo "# Check for Numba dependencies" >> /tmp/numba_checks.sh     && echo "check_cmd llvm-config 'LLVM Configurat  0.1s 
 => exporting to image                                                                                                          62.8s 
 => => exporting layers                                                                                                         31.4s 
 => => exporting manifest sha256:cfe216b94d49adf172c8954ec28457d1d59b259ae9d6f175b65b0ea296c7f3cf                                0.0s 
 => => exporting config sha256:e0d6ce5143eb0b983d0901d205a03b05b88bfa15dfe5cdc63b80bc52e342f20f                                  0.0s 
 => => exporting attestation manifest sha256:95d9392d4f0b9ffae8cc453e1420e4a64a10ae4122a4cdd445004703e4519124                    0.0s 
 => => exporting manifest list sha256:a0ca317c7500f7ae145991c04fdde3ef22279f4d9d2586781a6c7f65c5ea1472                           0.0s
 => => pushing layers                                                                                                           28.7s
 => => pushing manifest for docker.io/kairin/001:01-01-numba@sha256:a0ca317c7500f7ae145991c04fdde3ef22279f4d9d2586781a6c7f65c5e  2.6s
 => [auth] kairin/001:pull,push token for registry-1.docker.io                                                                   0.0s

 1 warning found (use docker --debug to expand):
 - RedundantTargetPlatform: Setting platform to predefined $TARGETPLATFORM in FROM is redundant as this is the default behavior (line 17)
Successfully built image: kairin/001:01-01-numba
Pulling image kairin/001:01-01-numba to ensure it's available locally...
01-01-numba: Pulling from kairin/001
14fcbe0c9272: Already exists 
9c92e5240789: Already exists 
0de21df19981: Already exists 
6dbc88b20006: Already exists 
34ab0cf6029d: Already exists 
f04e366e1ed2: Already exists 
6c480dbc6889: Already exists 
5befcb58f7f1: Pull complete 
4f4fb700ef54: Pull complete 
19c975fb6c77: Pull complete 
Digest: sha256:a0ca317c7500f7ae145991c04fdde3ef22279f4d9d2586781a6c7f65c5ea1472
Status: Downloaded newer image for kairin/001:01-01-numba
docker.io/kairin/001:01-01-numba
Successfully pulled image kairin/001:01-01-numba.
Image kairin/001:01-01-numba verified locally after pull.
Successfully built, pushed, and pulled numbered image: kairin/001:01-01-numba
Next base image will be: kairin/001:01-01-numba
Processing numbered directory: build/01-01-numpy
Using base image: kairin/001:01-01-numba
--------------------------------------------------
