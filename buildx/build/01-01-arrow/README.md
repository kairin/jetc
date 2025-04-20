Building image from folder: build/01-01-arrow
Image Name: 01-01-arrow
Platform: linux/arm64
Tag: kairin/001:01-01-arrow
Base Image (FROM via ARG): kairin/001:01-00-build-essential
Skip Intermediate Push/Pull: n
--------------------------------------------------
Found .buildargs file: build/01-01-arrow/.buildargs
  Adding build arg: --build-arg ARROW_BRANCH="apache-arrow-16.1.0"
Using --no-cache
Using --push
Running: docker buildx build --platform linux/arm64 -t kairin/001:01-01-arrow --build-arg BASE_IMAGE=kairin/001:01-00-build-essential --build-arg ARROW_BRANCH="apache-arrow-16.1.0" --no-cache --push build/01-01-arrow
[+] Building 17.1s (6/11)                                                                             docker-container:jetson-builder
 => [internal] load build definition from Dockerfile                                                                             0.0s
 => => transferring dockerfile: 2.87kB                                                                                           0.0s
 => WARN: RedundantTargetPlatform: Setting platform to predefined $TARGETPLATFORM in FROM is redundant as this is the default b  0.0s
 => [internal] load metadata for docker.io/kairin/001:01-00-build-essential                                                      0.3s
 => [internal] load .dockerignore                                                                                                0.0s
 => => transferring context: 2B                                                                                                  0.0s
 => [1/8] FROM docker.io/kairin/001:01-00-build-essential@sha256:aafe9bc88238dabfe9d5592079a38aec110d51a052e981cdfb225eb0cd5c77  0.1s
 => => resolve docker.io/kairin/001:01-00-build-essential@sha256:aafe9bc88238dabfe9d5592079a38aec110d51a052e981cdfb225eb0cd5c77  0.0s
 => [2/8] RUN git clone --branch=apache-arrow-16.1.0 --depth=1 --recursive https://github.com/apache/arrow /opt/arrow           11.2s
 => ERROR [3/8] RUN cd /opt/arrow/cpp &&     mkdir build &&     cd build &&     cmake       -DCMAKE_INSTALL_PREFIX=/usr/local    5.4s 
------                                                                                                                                
 > [3/8] RUN cd /opt/arrow/cpp &&     mkdir build &&     cd build &&     cmake       -DCMAKE_INSTALL_PREFIX=/usr/local   -DARROW_CUDA=ON       -DARROW_PYTHON=ON       -DARROW_COMPUTE=ON      -DARROW_CSV=ON          -DARROW_DATASET=ON      -DARROW_FILESYSTEM=ON   -DARROW_HDFS=ON       -DARROW_JSON=ON         -DARROW_PARQUET=ON      -DARROW_ORC=ON          -DARROW_WITH_BZ2=ON     -DARROW_WITH_LZ4=ON  -DARROW_WITH_SNAPPY=ON   -DARROW_WITH_ZLIB=ON    -DARROW_WITH_ZSTD=ON    ../ &&     make -j$(nproc) &&     make install:              
0.633 -- Building using CMake version: 3.31.6                                                                                         
0.861 -- The C compiler identification is GNU 13.3.0
0.990 -- The CXX compiler identification is GNU 13.3.0
1.028 -- Detecting C compiler ABI info
1.168 -- Detecting C compiler ABI info - done
1.212 -- Check for working C compiler: /usr/bin/cc - skipped
1.213 -- Detecting C compile features
1.215 -- Detecting C compile features - done
1.248 -- Detecting CXX compiler ABI info
1.381 -- Detecting CXX compiler ABI info - done
1.429 -- Check for working CXX compiler: /usr/bin/c++ - skipped
1.430 -- Detecting CXX compile features
1.432 -- Detecting CXX compile features - done
1.447 -- Arrow version: 16.1.0 (full: '16.1.0')
1.448 -- Arrow SO version: 1601 (full: 1601.0.0)
1.479 -- clang-tidy 14 not found
1.479 -- clang-format 14 not found
1.480 -- Could NOT find ClangTools (missing: CLANG_FORMAT_BIN CLANG_TIDY_BIN) 
1.481 -- infer not found
1.734 -- Found Python3: /usr/local/bin/python3 (found version "3.12.3") found components: Interpreter
1.769 -- Found cpplint executable at /opt/arrow/cpp/build-support/cpplint.py
1.773 -- System processor: aarch64
1.775 -- Performing Test CXX_SUPPORTS_SVE
1.898 -- Performing Test CXX_SUPPORTS_SVE - Success
1.899 -- Arrow build warning level: PRODUCTION
1.909 -- Using ld linker
1.909 -- Build Type: RELEASE
1.916 -- Performing Test CXX_LINKER_SUPPORTS_VERSION_SCRIPT
2.062 -- Performing Test CXX_LINKER_SUPPORTS_VERSION_SCRIPT - Success
2.086 -- Using AUTO approach to find dependencies
2.092 -- ARROW_ABSL_BUILD_VERSION: 20211102.0
2.092 -- ARROW_ABSL_BUILD_SHA256_CHECKSUM: dcf71b9cba8dc0ca9940c4b316a0c796be8fab42b070bb6b7cab62b48f0e66c4
2.092 -- ARROW_AWS_C_AUTH_BUILD_VERSION: v0.6.22
2.092 -- ARROW_AWS_C_AUTH_BUILD_SHA256_CHECKSUM: 691a6b4418afcd3dc141351b6ad33fccd8e3ff84df0e9e045b42295d284ee14c
2.092 -- ARROW_AWS_C_CAL_BUILD_VERSION: v0.5.20
2.092 -- ARROW_AWS_C_CAL_BUILD_SHA256_CHECKSUM: acc352359bd06f8597415c366cf4ec4f00d0b0da92d637039a73323dd55b6cd0
2.092 -- ARROW_AWS_C_COMMON_BUILD_VERSION: v0.8.9
2.092 -- ARROW_AWS_C_COMMON_BUILD_SHA256_CHECKSUM: 2f3fbaf7c38eae5a00e2a816d09b81177f93529ae8ba1b82dc8f31407565327a
2.092 -- ARROW_AWS_C_COMPRESSION_BUILD_VERSION: v0.2.16
2.092 -- ARROW_AWS_C_COMPRESSION_BUILD_SHA256_CHECKSUM: 044b1dbbca431a07bde8255ef9ec443c300fc60d4c9408d4b862f65e496687f4
2.092 -- ARROW_AWS_C_EVENT_STREAM_BUILD_VERSION: v0.2.18
2.092 -- ARROW_AWS_C_EVENT_STREAM_BUILD_SHA256_CHECKSUM: 310ca617f713bf664e4c7485a3d42c1fb57813abd0107e49790d107def7cde4f
2.093 -- ARROW_AWS_C_HTTP_BUILD_VERSION: v0.7.3
2.093 -- ARROW_AWS_C_HTTP_BUILD_SHA256_CHECKSUM: 07e16c6bf5eba6f0dea96b6f55eae312a7c95b736f4d2e4a210000f45d8265ae
2.093 -- ARROW_AWS_C_IO_BUILD_VERSION: v0.13.14
2.093 -- ARROW_AWS_C_IO_BUILD_SHA256_CHECKSUM: 12b66510c3d9a4f7e9b714e9cfab2a5bf835f8b9ce2f909d20ae2a2128608c71
2.093 -- ARROW_AWS_C_MQTT_BUILD_VERSION: v0.8.4
2.093 -- ARROW_AWS_C_MQTT_BUILD_SHA256_CHECKSUM: 232eeac63e72883d460c686a09b98cdd811d24579affac47c5c3f696f956773f
2.093 -- ARROW_AWS_C_S3_BUILD_VERSION: v0.2.3
2.093 -- ARROW_AWS_C_S3_BUILD_SHA256_CHECKSUM: a00b3c9f319cd1c9aa2c3fa15098864df94b066dcba0deaccbb3caa952d902fe
2.093 -- ARROW_AWS_C_SDKUTILS_BUILD_VERSION: v0.1.6
2.093 -- ARROW_AWS_C_SDKUTILS_BUILD_SHA256_CHECKSUM: 8a2951344b2fb541eab1e9ca17c18a7fcbfd2aaff4cdd31d362d1fad96111b91
2.093 -- ARROW_AWS_CHECKSUMS_BUILD_VERSION: v0.1.13
2.093 -- ARROW_AWS_CHECKSUMS_BUILD_SHA256_CHECKSUM: 0f897686f1963253c5069a0e495b85c31635ba146cd3ac38cc2ea31eaf54694d
2.093 -- ARROW_AWS_CRT_CPP_BUILD_VERSION: v0.18.16
2.093 -- ARROW_AWS_CRT_CPP_BUILD_SHA256_CHECKSUM: 9e69bc1dc4b50871d1038aa9ff6ddeb4c9b28f7d6b5e5b1b69041ccf50a13483
2.093 -- ARROW_AWS_LC_BUILD_VERSION: v1.3.0
2.093 -- ARROW_AWS_LC_BUILD_SHA256_CHECKSUM: ae96a3567161552744fc0cae8b4d68ed88b1ec0f3d3c98700070115356da5a37
2.093 -- ARROW_AWSSDK_BUILD_VERSION: 1.10.55
2.093 -- ARROW_AWSSDK_BUILD_SHA256_CHECKSUM: 2d552fb1a84bef4a9b65e34aa7031851ed2aef5319e02cc6e4cb735c48aa30de
2.093 -- ARROW_AZURE_SDK_BUILD_VERSION: azure-core_1.10.3
2.094 -- ARROW_AZURE_SDK_BUILD_SHA256_CHECKSUM: dd624c2f86adf474d2d0a23066be6e27af9cbd7e3f8d9d8fd7bf981e884b7b48
2.094 -- ARROW_BOOST_BUILD_VERSION: 1.81.0
2.094 -- ARROW_BOOST_BUILD_SHA256_CHECKSUM: 9e0ffae35528c35f90468997bc8d99500bf179cbae355415a89a600c38e13574
2.094 -- ARROW_BROTLI_BUILD_VERSION: v1.0.9
2.094 -- ARROW_BROTLI_BUILD_SHA256_CHECKSUM: f9e8d81d0405ba66d181529af42a3354f838c939095ff99930da6aa9cdf6fe46
2.094 -- ARROW_BZIP2_BUILD_VERSION: 1.0.8
2.094 -- ARROW_BZIP2_BUILD_SHA256_CHECKSUM: ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269
2.094 -- ARROW_CARES_BUILD_VERSION: 1.17.2
2.094 -- ARROW_CARES_BUILD_SHA256_CHECKSUM: 4803c844ce20ce510ef0eb83f8ea41fa24ecaae9d280c468c582d2bb25b3913d
2.094 -- ARROW_CRC32C_BUILD_VERSION: 1.1.2
2.094 -- ARROW_CRC32C_BUILD_SHA256_CHECKSUM: ac07840513072b7fcebda6e821068aa04889018f24e10e46181068fb214d7e56
2.094 -- ARROW_GBENCHMARK_BUILD_VERSION: v1.8.3
2.094 -- ARROW_GBENCHMARK_BUILD_SHA256_CHECKSUM: 6bc180a57d23d4d9515519f92b0c83d61b05b5bab188961f36ac7b06b0d9e9ce
2.095 -- ARROW_GFLAGS_BUILD_VERSION: v2.2.2
2.095 -- ARROW_GFLAGS_BUILD_SHA256_CHECKSUM: 34af2f15cf7367513b352bdcd2493ab14ce43692d2dcd9dfc499492966c64dcf
2.095 -- ARROW_GLOG_BUILD_VERSION: v0.5.0
2.095 -- ARROW_GLOG_BUILD_SHA256_CHECKSUM: eede71f28371bf39aa69b45de23b329d37214016e2055269b3b5e7cfd40b59f5
2.095 -- ARROW_GOOGLE_CLOUD_CPP_BUILD_VERSION: v2.12.0
2.095 -- ARROW_GOOGLE_CLOUD_CPP_BUILD_SHA256_CHECKSUM: 8cda870803925c62de8716a765e03eb9d34249977e5cdb7d0d20367e997a55e2
2.095 -- ARROW_GRPC_BUILD_VERSION: v1.46.3
2.095 -- ARROW_GRPC_BUILD_SHA256_CHECKSUM: d6cbf22cb5007af71b61c6be316a79397469c58c82a942552a62e708bce60964
2.095 -- ARROW_GTEST_BUILD_VERSION: 1.11.0
2.096 -- ARROW_GTEST_BUILD_SHA256_CHECKSUM: b4870bf121ff7795ba20d20bcdd8627b8e088f2d1dab299a031c1034eddc93d5
2.096 -- ARROW_JEMALLOC_BUILD_VERSION: 5.3.0
2.096 -- ARROW_JEMALLOC_BUILD_SHA256_CHECKSUM: 2db82d1e7119df3e71b7640219b6dfe84789bc0537983c3b7ac4f7189aecfeaa
2.096 -- ARROW_LZ4_BUILD_VERSION: v1.9.4
2.096 -- ARROW_LZ4_BUILD_SHA256_CHECKSUM: 0b0e3aa07c8c063ddf40b082bdf7e37a1562bda40a0ff5272957f3e987e0e54b
2.096 -- ARROW_MIMALLOC_BUILD_VERSION: v2.0.6
2.096 -- ARROW_MIMALLOC_BUILD_SHA256_CHECKSUM: 9f05c94cc2b017ed13698834ac2a3567b6339a8bde27640df5a1581d49d05ce5
2.097 -- ARROW_NLOHMANN_JSON_BUILD_VERSION: v3.10.5
2.097 -- ARROW_NLOHMANN_JSON_BUILD_SHA256_CHECKSUM: 5daca6ca216495edf89d167f808d1d03c4a4d929cef7da5e10f135ae1540c7e4
2.097 -- ARROW_OPENTELEMETRY_BUILD_VERSION: v1.8.1
2.097 -- ARROW_OPENTELEMETRY_BUILD_SHA256_CHECKSUM: 3d640201594b07f08dade9cd1017bd0b59674daca26223b560b9bb6bf56264c2
2.097 -- ARROW_OPENTELEMETRY_PROTO_BUILD_VERSION: v0.17.0
2.097 -- ARROW_OPENTELEMETRY_PROTO_BUILD_SHA256_CHECKSUM: f269fbcb30e17b03caa1decd231ce826e59d7651c0f71c3b28eb5140b4bb5412
2.097 -- ARROW_ORC_BUILD_VERSION: 2.0.0
2.097 -- ARROW_ORC_BUILD_SHA256_CHECKSUM: 9107730919c29eb39efaff1b9e36166634d1d4d9477e5fee76bfd6a8fec317df
2.097 -- ARROW_PROTOBUF_BUILD_VERSION: v21.3
2.098 -- ARROW_PROTOBUF_BUILD_SHA256_CHECKSUM: 2f723218f6cb709ae4cdc4fb5ed56a5951fc5d466f0128ce4c946b8c78c8c49f
2.098 -- ARROW_RAPIDJSON_BUILD_VERSION: 232389d4f1012dddec4ef84861face2d2ba85709
2.098 -- ARROW_RAPIDJSON_BUILD_SHA256_CHECKSUM: b9290a9a6d444c8e049bd589ab804e0ccf2b05dc5984a19ed5ae75d090064806
2.098 -- ARROW_RE2_BUILD_VERSION: 2022-06-01
2.098 -- ARROW_RE2_BUILD_SHA256_CHECKSUM: f89c61410a072e5cbcf8c27e3a778da7d6fd2f2b5b1445cd4f4508bee946ab0f
2.098 -- ARROW_SNAPPY_BUILD_VERSION: 1.1.10
2.098 -- ARROW_SNAPPY_BUILD_SHA256_CHECKSUM: 49d831bffcc5f3d01482340fe5af59852ca2fe76c3e05df0e67203ebbe0f1d90
2.098 -- ARROW_SUBSTRAIT_BUILD_VERSION: v0.44.0
2.099 -- ARROW_SUBSTRAIT_BUILD_SHA256_CHECKSUM: f989a862f694e7dbb695925ddb7c4ce06aa6c51aca945105c075139aed7e55a2
2.099 -- ARROW_S2N_TLS_BUILD_VERSION: v1.3.35
2.099 -- ARROW_S2N_TLS_BUILD_SHA256_CHECKSUM: 9d32b26e6bfcc058d98248bf8fc231537e347395dd89cf62bb432b55c5da990d
2.099 -- ARROW_THRIFT_BUILD_VERSION: 0.16.0
2.099 -- ARROW_THRIFT_BUILD_SHA256_CHECKSUM: f460b5c1ca30d8918ff95ea3eb6291b3951cf518553566088f3f2be8981f6209
2.099 -- ARROW_UCX_BUILD_VERSION: 1.12.1
2.099 -- ARROW_UCX_BUILD_SHA256_CHECKSUM: 9bef31aed0e28bf1973d28d74d9ac4f8926c43ca3b7010bd22a084e164e31b71
2.099 -- ARROW_UTF8PROC_BUILD_VERSION: v2.7.0
2.099 -- ARROW_UTF8PROC_BUILD_SHA256_CHECKSUM: 4bb121e297293c0fd55f08f83afab6d35d48f0af4ecc07523ad8ec99aa2b12a1
2.100 -- ARROW_XSIMD_BUILD_VERSION: 9.0.1
2.100 -- ARROW_XSIMD_BUILD_SHA256_CHECKSUM: b1bb5f92167fd3a4f25749db0be7e61ed37e0a5d943490f3accdcd2cd2918cc0
2.100 -- ARROW_ZLIB_BUILD_VERSION: 1.3.1
2.100 -- ARROW_ZLIB_BUILD_SHA256_CHECKSUM: 9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23
2.100 -- ARROW_ZSTD_BUILD_VERSION: 1.5.6
2.100 -- ARROW_ZSTD_BUILD_SHA256_CHECKSUM: 8c29e06cf42aacc1eafc4077ae2ec6c6fcb96a626157e0593d5e82a34fd403c1
2.121 -- Performing Test CMAKE_HAVE_LIBC_PTHREAD
2.260 -- Performing Test CMAKE_HAVE_LIBC_PTHREAD - Success
2.264 -- Found Threads: TRUE
2.266 -- Looking for _M_ARM64
2.347 -- Looking for _M_ARM64 - not found
2.348 -- Looking for __SIZEOF_INT128__
2.489 -- Looking for __SIZEOF_INT128__ - found
2.491 CMake Warning (dev) at cmake_modules/ThirdpartyToolchain.cmake:291 (find_package):
2.491   Policy CMP0167 is not set: The FindBoost module is removed.  Run "cmake
2.491   --help-policy CMP0167" for policy details.  Use the cmake_policy command to
2.491   set the policy and suppress this warning.
2.491 
2.491 Call Stack (most recent call first):
2.491   cmake_modules/ThirdpartyToolchain.cmake:1288 (resolve_dependency)
2.491   CMakeLists.txt:543 (include)
2.491 This warning is for project developers.  Use -Wno-dev to suppress it.
2.491 
2.591 -- Could NOT find Boost (missing: Boost_INCLUDE_DIR) (Required is at least version "1.58")
2.621 -- Boost include dir: Boost_INCLUDE_DIR-NOTFOUND
2.626 -- Providing CMake module for FindSnappyAlt as part of Arrow CMake package
2.716 -- Using pkg-config package for snappy that is used by arrow for static link
2.717 -- Building without OpenSSL support. Minimum OpenSSL version 1.0.2 required.
2.731 CMake Warning at cmake_modules/FindThriftAlt.cmake:56 (find_package):
2.731   By not providing "FindThrift.cmake" in CMAKE_MODULE_PATH this project has
2.731   asked CMake to find a package configuration file provided by "Thrift", but
2.731   CMake did not find one.
2.731 
2.731   Could not find a package configuration file provided by "Thrift" (requested
2.731   version 0.11.0) with any of the following names:
2.731 
2.731     ThriftConfig.cmake
2.731     thrift-config.cmake
2.731 
2.731   Add the installation prefix of "Thrift" to CMAKE_PREFIX_PATH or set
2.731   "Thrift_DIR" to a directory containing one of the above files.  If "Thrift"
2.731   provides a separate development package or SDK, be sure it has been
2.731   installed.
2.731 Call Stack (most recent call first):
2.731   cmake_modules/ThirdpartyToolchain.cmake:291 (find_package)
2.731   cmake_modules/ThirdpartyToolchain.cmake:1772 (resolve_dependency)
2.731   CMakeLists.txt:543 (include)
2.731 
2.731 
2.743 -- Checking for module 'thrift'
2.832 --   Package 'thrift', required by 'virtual:world', not found
2.848 -- Could NOT find ThriftAlt: (Required is at least version "0.11.0") (found ThriftAlt_LIB-NOTFOUND)
2.848 -- Building Apache Thrift from source
2.906 -- Could NOT find protobuf (missing: protobuf_DIR)
2.952 -- Found Protobuf: /usr/lib/aarch64-linux-gnu/libprotobuf.so (found version "3.21.12")
2.953 -- Providing CMake module for FindProtobufAlt as part of Arrow CMake package
3.036 -- Using pkg-config package for protobuf that is used by arrow for static link
3.036 -- Found protoc: /usr/bin/protoc
3.037 -- Building jemalloc from source
3.083 -- RapidJSON found. Headers: /usr/include
3.093 CMake Warning at cmake_modules/ThirdpartyToolchain.cmake:291 (find_package):
3.093   By not providing "Findxsimd.cmake" in CMAKE_MODULE_PATH this project has
3.093   asked CMake to find a package configuration file provided by "xsimd", but
3.093   CMake did not find one.
3.093 
3.093   Could not find a package configuration file provided by "xsimd" with any of
3.093   the following names:
3.093 
3.093     xsimdConfig.cmake
3.093     xsimd-config.cmake
3.093 
3.093   Add the installation prefix of "xsimd" to CMAKE_PREFIX_PATH or set
3.093   "xsimd_DIR" to a directory containing one of the above files.  If "xsimd"
3.093   provides a separate development package or SDK, be sure it has been
3.093   installed.
3.093 Call Stack (most recent call first):
3.093   cmake_modules/ThirdpartyToolchain.cmake:2491 (resolve_dependency)
3.093   CMakeLists.txt:543 (include)
3.093 
3.093 
3.093 -- Building xsimd from source
3.144 -- Found ZLIB: /usr/lib/aarch64-linux-gnu/libz.so (found version "1.3")
3.233 -- Using pkg-config package for zlib that is used by arrow for static link
3.246 CMake Warning at cmake_modules/Findlz4Alt.cmake:29 (find_package):
3.246   By not providing "Findlz4.cmake" in CMAKE_MODULE_PATH this project has
3.246   asked CMake to find a package configuration file provided by "lz4", but
3.246   CMake did not find one.
3.246 
3.246   Could not find a package configuration file provided by "lz4" with any of
3.246   the following names:
3.246 
3.246     lz4Config.cmake
3.246     lz4-config.cmake
3.246 
3.246   Add the installation prefix of "lz4" to CMAKE_PREFIX_PATH or set "lz4_DIR"
3.246   to a directory containing one of the above files.  If "lz4" provides a
3.246   separate development package or SDK, be sure it has been installed.
3.246 Call Stack (most recent call first):
3.246   cmake_modules/ThirdpartyToolchain.cmake:291 (find_package)
3.246   cmake_modules/ThirdpartyToolchain.cmake:2599 (resolve_dependency)
3.246   CMakeLists.txt:543 (include)
3.246 
3.246 
3.255 -- Checking for module 'liblz4'
3.275 --   Found liblz4, version 1.9.4
3.334 -- Found lz4Alt: /usr/lib/aarch64-linux-gnu/liblz4.so
3.336 -- Providing CMake module for Findlz4Alt as part of Arrow CMake package
3.415 -- Using pkg-config package for liblz4 that is used by arrow for static link
3.424 -- Providing CMake module for FindzstdAlt as part of Arrow CMake package
3.523 -- Using pkg-config package for libzstd that is used by arrow for static link
3.523 -- Found Zstandard: zstd::libzstd_shared
3.541 CMake Warning at cmake_modules/Findre2Alt.cmake:29 (find_package):
3.541   By not providing "Findre2.cmake" in CMAKE_MODULE_PATH this project has
3.541   asked CMake to find a package configuration file provided by "re2", but
3.541   CMake did not find one.
3.541 
3.541   Could not find a package configuration file provided by "re2" with any of
3.541   the following names:
3.541 
3.541     re2Config.cmake
3.541     re2-config.cmake
3.541 
3.541   Add the installation prefix of "re2" to CMAKE_PREFIX_PATH or set "re2_DIR"
3.541   to a directory containing one of the above files.  If "re2" provides a
3.541   separate development package or SDK, be sure it has been installed.
3.541 Call Stack (most recent call first):
3.541   cmake_modules/ThirdpartyToolchain.cmake:291 (find_package)
3.541   cmake_modules/ThirdpartyToolchain.cmake:2711 (resolve_dependency)
3.541   CMakeLists.txt:543 (include)
3.541 
3.541 
3.556 -- Checking for module 're2'
3.574 --   Found re2, version 10.0.0
3.635 -- Found re2Alt: /usr/lib/aarch64-linux-gnu/libre2.so
3.636 -- Providing CMake module for Findre2Alt as part of Arrow CMake package
3.724 -- Using pkg-config package for re2 that is used by arrow for static link
3.738 -- Found BZip2: /usr/lib/aarch64-linux-gnu/libbz2.so (found version "1.0.8")
3.741 -- Looking for BZ2_bzCompressInit
3.880 -- Looking for BZ2_bzCompressInit - found
3.912 -- pkg-config package for bzip2 that is used by arrow for static link isn't found
3.922 -- Could NOT find utf8proc: (Required is at least version "2.2.0") (found utf8proc_LIB-NOTFOUND)
3.922 -- Building utf8proc from source
3.967 -- Found hdfs.h at: /opt/arrow/cpp/thirdparty/hadoop/include/hdfs.h
3.976 CMake Warning at cmake_modules/FindorcAlt.cmake:29 (find_package):
3.976   By not providing "Findorc.cmake" in CMAKE_MODULE_PATH this project has
3.976   asked CMake to find a package configuration file provided by "orc", but
3.976   CMake did not find one.
3.976 
3.976   Could not find a package configuration file provided by "orc" with any of
3.976   the following names:
3.976 
3.976     orcConfig.cmake
3.976     orc-config.cmake
3.976 
3.976   Add the installation prefix of "orc" to CMAKE_PREFIX_PATH or set "orc_DIR"
3.976   to a directory containing one of the above files.  If "orc" provides a
3.976   separate development package or SDK, be sure it has been installed.
3.976 Call Stack (most recent call first):
3.976   cmake_modules/ThirdpartyToolchain.cmake:291 (find_package)
3.976   cmake_modules/ThirdpartyToolchain.cmake:4578 (resolve_dependency)
3.976   CMakeLists.txt:543 (include)
3.976 
3.976 
3.980 -- Could NOT find orcAlt (missing: ORC_STATIC_LIB ORC_INCLUDE_DIR) 
3.980 -- Building Apache ORC from source
4.009 -- Found ORC static library: /opt/arrow/cpp/build/orc_ep-install/lib/liborc.a
4.010 -- Found ORC headers: /opt/arrow/cpp/build/orc_ep-install/include
4.011 -- All bundled static libraries: thrift::thrift;jemalloc::jemalloc;utf8proc::utf8proc;orc::orc
4.012 -- CMAKE_C_FLAGS:   -Wall -fno-semantic-interposition -march=armv8-a 
4.012 -- CMAKE_CXX_FLAGS:  -Wno-noexcept-type -Wno-self-move  -fdiagnostics-color=always  -Wall -fno-semantic-interposition -march=armv8-a 
4.012 -- CMAKE_C_FLAGS_RELEASE: -O3 -DNDEBUG -O2 -ftree-vectorize 
4.012 -- CMAKE_CXX_FLAGS_RELEASE: -O3 -DNDEBUG -O2 -ftree-vectorize 
4.022 -- Creating bundled static library target arrow_bundled_dependencies at /opt/arrow/cpp/build/release/libarrow_bundled_dependencies.a
4.474 CMake Warning (dev) at src/arrow/CMakeLists.txt:1054 (install):
4.474   Policy CMP0177 is not set: install() DESTINATION paths are normalized.  Run
4.474   "cmake --help-policy CMP0177" for policy details.  Use the cmake_policy
4.474   command to set the policy and suppress this warning.
4.474 This warning is for project developers.  Use -Wno-dev to suppress it.
4.474 
4.482 -- Looking for backtrace
4.618 -- Looking for backtrace - found
4.619 -- backtrace facility detected in default set of libraries
4.620 -- Found Backtrace: /usr/include
4.751 -- Found CUDAToolkit: /usr/local/cuda/targets/aarch64-linux/include (found version "12.8.93")
4.923 -- ---------------------------------------------------------------------
4.923 -- Arrow version:                                 16.1.0
4.923 -- 
4.923 -- Build configuration summary:
4.923 --   Generator: Unix Makefiles
4.923 --   Build type: RELEASE
4.923 --   Source directory: /opt/arrow/cpp
4.923 --   Install prefix: /usr/local
4.923 -- 
4.923 -- Compile and link options:
4.923 -- 
4.923 --   ARROW_CXXFLAGS="" [default=""]
4.923 --       Compiler flags to append when compiling Arrow
4.923 --   ARROW_BUILD_STATIC=ON [default=ON]
4.923 --       Build static libraries
4.923 --   ARROW_BUILD_SHARED=ON [default=ON]
4.923 --       Build shared libraries
4.923 --   ARROW_PACKAGE_KIND="" [default=""]
4.923 --       Arbitrary string that identifies the kind of package
4.923 --       (for informational purposes)
4.923 --   ARROW_GIT_ID=7dd1d34074af176d9e861a360e135ae57b21cf96 [default=""]
4.923 --       The Arrow git commit id (if any)
4.923 --   ARROW_GIT_DESCRIPTION=apache-arrow-16.1.0 [default=""]
4.923 --       The Arrow git commit description (if any)
4.923 --   ARROW_NO_DEPRECATED_API=OFF [default=OFF]
4.923 --       Exclude deprecated APIs from build
4.923 --   ARROW_POSITION_INDEPENDENT_CODE=ON [default=ON]
4.923 --       Whether to create position-independent target
4.923 --   ARROW_USE_CCACHE=ON [default=ON]
4.923 --       Use ccache when compiling (if available)
4.924 --   ARROW_USE_SCCACHE=ON [default=ON]
4.924 --       Use sccache when compiling (if available),
4.924 --       takes precedence over ccache if a storage backend is configured
4.924 --   ARROW_USE_LD_GOLD=OFF [default=OFF]
4.924 --       Use ld.gold for linking on Linux (if available)
4.924 --   ARROW_USE_LLD=OFF [default=OFF]
4.924 --       Use the LLVM lld for linking (if available)
4.924 --   ARROW_USE_MOLD=OFF [default=OFF]
4.924 --       Use mold for linking on Linux (if available)
4.924 --   ARROW_USE_PRECOMPILED_HEADERS=OFF [default=OFF]
4.924 --       Use precompiled headers when compiling
4.924 --   ARROW_SIMD_LEVEL=NEON [default=DEFAULT|NONE|SSE4_2|AVX2|AVX512|NEON|SVE|SVE128|SVE256|SVE512]
4.924 --       Compile-time SIMD optimization level
4.924 --   ARROW_RUNTIME_SIMD_LEVEL=MAX [default=MAX|NONE|SSE4_2|AVX2|AVX512]
4.924 --       Max runtime SIMD optimization level
4.924 --   ARROW_ALTIVEC=ON [default=ON]
4.924 --       Build with Altivec if compiler has support
4.924 --   ARROW_RPATH_ORIGIN=OFF [default=OFF]
4.924 --       Build Arrow libraries with RATH set to $ORIGIN
4.924 --   ARROW_INSTALL_NAME_RPATH=ON [default=ON]
4.924 --       Build Arrow libraries with install_name set to @rpath
4.924 --   ARROW_GGDB_DEBUG=ON [default=ON]
4.924 --       Pass -ggdb flag to debug builds
4.924 --   ARROW_WITH_MUSL=OFF [default=OFF]
4.924 --       Whether the system libc is musl or not
4.924 --   ARROW_ENABLE_THREADING=ON [default=ON]
4.924 --       Enable threading in Arrow core
4.924 -- 
4.924 -- Test and benchmark options:
4.924 -- 
4.924 --   ARROW_BUILD_EXAMPLES=OFF [default=OFF]
4.924 --       Build the Arrow examples
4.924 --   ARROW_BUILD_TESTS=OFF [default=OFF]
4.924 --       Build the Arrow googletest unit tests
4.924 --   ARROW_ENABLE_TIMING_TESTS=ON [default=ON]
4.925 --       Enable timing-sensitive tests
4.925 --   ARROW_BUILD_INTEGRATION=OFF [default=OFF]
4.925 --       Build the Arrow integration test executables
4.925 --   ARROW_BUILD_BENCHMARKS=OFF [default=OFF]
4.925 --       Build the Arrow micro benchmarks
4.925 --   ARROW_BUILD_BENCHMARKS_REFERENCE=OFF [default=OFF]
4.925 --       Build the Arrow micro reference benchmarks
4.925 --   ARROW_BUILD_OPENMP_BENCHMARKS=OFF [default=OFF]
4.925 --       Build the Arrow benchmarks that rely on OpenMP
4.925 --   ARROW_BUILD_DETAILED_BENCHMARKS=OFF [default=OFF]
4.925 --       Build benchmarks that do a longer exploration of performance
4.925 --   ARROW_TEST_LINKAGE=shared [default=shared|static]
4.925 --       Linkage of Arrow libraries with unit tests executables.
4.925 --   ARROW_FUZZING=OFF [default=OFF]
4.925 --       Build Arrow Fuzzing executables
4.925 --   ARROW_LARGE_MEMORY_TESTS=OFF [default=OFF]
4.925 --       Enable unit tests which use large memory
4.925 -- 
4.925 -- Lint options:
4.925 -- 
4.925 --   ARROW_ONLY_LINT=OFF [default=OFF]
4.925 --       Only define the lint and check-format targets
4.925 --   ARROW_VERBOSE_LINT=OFF [default=OFF]
4.925 --       If off, 'quiet' flags will be passed to linting tools
4.925 --   ARROW_GENERATE_COVERAGE=OFF [default=OFF]
4.925 --       Build with C++ code coverage enabled
4.925 -- 
4.925 -- Checks options:
4.925 -- 
4.925 --   ARROW_TEST_MEMCHECK=OFF [default=OFF]
4.925 --       Run the test suite using valgrind --tool=memcheck
4.925 --   ARROW_USE_ASAN=OFF [default=OFF]
4.925 --       Enable Address Sanitizer checks
4.925 --   ARROW_USE_TSAN=OFF [default=OFF]
4.925 --       Enable Thread Sanitizer checks
4.925 --   ARROW_USE_UBSAN=OFF [default=OFF]
4.925 --       Enable Undefined Behavior sanitizer checks
4.925 -- 
4.925 -- Project component options:
4.925 -- 
4.925 --   ARROW_ACERO=ON [default=OFF]
4.925 --       Build the Arrow Acero Engine Module
4.925 --   ARROW_AZURE=OFF [default=OFF]
4.925 --       Build Arrow with Azure support (requires the Azure SDK for C++)
4.926 --   ARROW_BUILD_UTILITIES=OFF [default=OFF]
4.926 --       Build Arrow commandline utilities
4.926 --   ARROW_COMPUTE=ON [default=OFF]
4.926 --       Build all Arrow Compute kernels
4.926 --   ARROW_CSV=ON [default=OFF]
4.926 --       Build the Arrow CSV Parser Module
4.926 --   ARROW_CUDA=ON [default=OFF]
4.926 --       Build the Arrow CUDA extensions (requires CUDA toolkit)
4.926 --   ARROW_DATASET=ON [default=OFF]
4.926 --       Build the Arrow Dataset Modules
4.926 --   ARROW_FILESYSTEM=ON [default=OFF]
4.926 --       Build the Arrow Filesystem Layer
4.926 --   ARROW_FLIGHT=OFF [default=OFF]
4.926 --       Build the Arrow Flight RPC System (requires GRPC, Protocol Buffers)
4.926 --   ARROW_FLIGHT_SQL=OFF [default=OFF]
4.926 --       Build the Arrow Flight SQL extension
4.926 --   ARROW_GANDIVA=OFF [default=OFF]
4.926 --       Build the Gandiva libraries
4.926 --   ARROW_GCS=OFF [default=OFF]
4.926 --       Build Arrow with GCS support (requires the GCloud SDK for C++)
4.926 --   ARROW_HDFS=ON [default=OFF]
4.926 --       Build the Arrow HDFS bridge
4.926 --   ARROW_IPC=ON [default=ON]
4.926 --       Build the Arrow IPC extensions
4.926 --   ARROW_JEMALLOC=ON [default=ON]
4.926 --       Build the Arrow jemalloc-based allocator
4.926 --   ARROW_JSON=ON [default=OFF]
4.926 --       Build Arrow with JSON support (requires RapidJSON)
4.926 --   ARROW_MIMALLOC=OFF [default=OFF]
4.926 --       Build the Arrow mimalloc-based allocator
4.926 --   ARROW_PARQUET=ON [default=OFF]
4.926 --       Build the Parquet libraries
4.927 --   ARROW_ORC=ON [default=OFF]
4.927 --       Build the Arrow ORC adapter
4.927 --   ARROW_PYTHON=ON [default=OFF]
4.927 --       Build some components needed by PyArrow.
4.927 --       (This is a deprecated option. Use CMake presets instead.)
4.927 --   ARROW_S3=OFF [default=OFF]
4.927 --       Build Arrow with S3 support (requires the AWS SDK for C++)
4.927 --   ARROW_SKYHOOK=OFF [default=OFF]
4.927 --       Build the Skyhook libraries
4.927 --   ARROW_SUBSTRAIT=OFF [default=OFF]
4.927 --       Build the Arrow Substrait Consumer Module
4.927 --   ARROW_TENSORFLOW=OFF [default=OFF]
4.927 --       Build Arrow with TensorFlow support enabled
4.927 --   ARROW_TESTING=OFF [default=OFF]
4.927 --       Build the Arrow testing libraries
4.927 -- 
4.927 -- Thirdparty toolchain options:
4.927 -- 
4.927 --   ARROW_DEPENDENCY_SOURCE=AUTO [default=AUTO|BUNDLED|SYSTEM|CONDA|VCPKG|BREW]
4.927 --       Method to use for acquiring arrow's build dependencies
4.927 --   ARROW_VERBOSE_THIRDPARTY_BUILD=OFF [default=OFF]
4.927 --       Show output from ExternalProjects rather than just logging to files
4.927 --   ARROW_DEPENDENCY_USE_SHARED=ON [default=ON]
4.927 --       Link to shared libraries
4.927 --   ARROW_BOOST_USE_SHARED=ON [default=ON]
4.927 --       Rely on Boost shared libraries where relevant
4.927 --   ARROW_BROTLI_USE_SHARED=ON [default=ON]
4.927 --       Rely on Brotli shared libraries where relevant
4.927 --   ARROW_BZ2_USE_SHARED=ON [default=ON]
4.927 --       Rely on Bz2 shared libraries where relevant
4.927 --   ARROW_GFLAGS_USE_SHARED=ON [default=ON]
4.927 --       Rely on GFlags shared libraries where relevant
4.927 --   ARROW_GRPC_USE_SHARED=ON [default=ON]
4.927 --       Rely on gRPC shared libraries where relevant
4.927 --   ARROW_JEMALLOC_USE_SHARED=OFF [default=ON]
4.927 --       Rely on jemalloc shared libraries where relevant
4.927 --   ARROW_LLVM_USE_SHARED=ON [default=ON]
4.927 --       Rely on LLVM shared libraries where relevant
4.927 --   ARROW_LZ4_USE_SHARED=ON [default=ON]
4.927 --       Rely on lz4 shared libraries where relevant
4.928 --   ARROW_OPENSSL_USE_SHARED=ON [default=ON]
4.928 --       Rely on OpenSSL shared libraries where relevant
4.928 --   ARROW_PROTOBUF_USE_SHARED=ON [default=ON]
4.928 --       Rely on Protocol Buffers shared libraries where relevant
4.928 --   ARROW_SNAPPY_USE_SHARED=ON [default=ON]
4.928 --       Rely on snappy shared libraries where relevant
4.928 --   ARROW_THRIFT_USE_SHARED=ON [default=ON]
4.928 --       Rely on thrift shared libraries where relevant
4.928 --   ARROW_UTF8PROC_USE_SHARED=ON [default=ON]
4.928 --       Rely on utf8proc shared libraries where relevant
4.928 --   ARROW_ZSTD_USE_SHARED=ON [default=ON]
4.928 --       Rely on zstd shared libraries where relevant
4.928 --   ARROW_USE_GLOG=OFF [default=OFF]
4.928 --       Build libraries with glog support for pluggable logging
4.928 --   ARROW_WITH_BACKTRACE=ON [default=ON]
4.928 --       Build with backtrace support
4.928 --   ARROW_WITH_OPENTELEMETRY=OFF [default=OFF]
4.928 --       Build libraries with OpenTelemetry support for distributed tracing
4.928 --   ARROW_WITH_BROTLI=OFF [default=OFF]
4.928 --       Build with Brotli compression
4.928 --   ARROW_WITH_BZ2=ON [default=OFF]
4.928 --       Build with BZ2 compression
4.928 --   ARROW_WITH_LZ4=ON [default=OFF]
4.928 --       Build with lz4 compression
4.928 --   ARROW_WITH_SNAPPY=ON [default=OFF]
4.928 --       Build with Snappy compression
4.928 --   ARROW_WITH_ZLIB=ON [default=OFF]
4.928 --       Build with zlib compression
4.928 --   ARROW_WITH_ZSTD=ON [default=OFF]
4.928 --       Build with zstd compression
4.928 --   ARROW_WITH_UCX=OFF [default=OFF]
4.928 --       Build with UCX transport for Arrow Flight
4.928 --       (only used if ARROW_FLIGHT is ON)
4.928 --   ARROW_WITH_UTF8PROC=ON [default=ON]
4.928 --       Build with support for Unicode properties using the utf8proc library
4.928 --       (only used if ARROW_COMPUTE is ON or ARROW_GANDIVA is ON)
4.929 --   ARROW_WITH_RE2=ON [default=ON]
4.929 --       Build with support for regular expressions using the re2 library
4.929 --       (only used if ARROW_COMPUTE or ARROW_GANDIVA is ON)
4.929 -- 
4.929 -- Parquet options:
4.929 -- 
4.929 --   PARQUET_MINIMAL_DEPENDENCY=OFF [default=OFF]
4.929 --       Depend only on Thirdparty headers to build libparquet.
4.929 --       Always OFF if building binaries
4.929 --   PARQUET_BUILD_EXECUTABLES=OFF [default=OFF]
4.929 --       Build the Parquet executable CLI tools. Requires static libraries to be built.
4.929 --   PARQUET_BUILD_EXAMPLES=OFF [default=OFF]
4.929 --       Build the Parquet examples. Requires static libraries to be built.
4.929 --   PARQUET_REQUIRE_ENCRYPTION=OFF [default=OFF]
4.929 --       Build support for encryption. Fail if OpenSSL is not found
4.929 -- 
4.929 -- Gandiva options:
4.929 -- 
4.929 --   ARROW_GANDIVA_STATIC_LIBSTDCPP=OFF [default=OFF]
4.929 --       Include -static-libstdc++ -static-libgcc when linking with
4.929 --       Gandiva static libraries
4.929 --   ARROW_GANDIVA_PC_CXX_FLAGS="" [default=""]
4.929 --       Compiler flags to append when pre-compiling Gandiva operations
4.929 -- 
4.929 -- Advanced developer options:
4.929 -- 
4.929 --   ARROW_EXTRA_ERROR_CONTEXT=OFF [default=OFF]
4.929 --       Compile with extra error context (line numbers, code)
4.929 --   ARROW_OPTIONAL_INSTALL=OFF [default=OFF]
4.929 --       If enabled install ONLY targets that have already been built. Please be
4.929 --       advised that if this is enabled 'install' will fail silently on components
4.929 --       that have not been built
4.929 --   ARROW_GDB_INSTALL_DIR="" [default=""]
4.929 --       Use a custom install directory for GDB plugin.
4.929 --       In general, you don't need to specify this because the default
4.929 --       (CMAKE_INSTALL_FULL_BINDIR on Windows, CMAKE_INSTALL_FULL_LIBDIR otherwise)
4.929 --       is reasonable.
4.929 CMake Warning at cmake_modules/DefineOptions.cmake:716 (message):
4.929   ARROW_PYTHON is deprecated.  Use CMake presets instead.
4.929 Call Stack (most recent call first):
4.929   CMakeLists.txt:756 (config_summary_message)
4.929 
4.929 
4.929 --   Outputting build configuration summary to /opt/arrow/cpp/build/cmake_summary.json
4.938 -- Configuring done (4.3s)
5.033 CMake Error at /usr/local/lib/python3.12/dist-packages/cmake/data/share/cmake-3.31/Modules/ExternalProject.cmake:1816 (file):
5.033   Error evaluating generator expression:
5.033 
5.033     $<TARGET_FILE:protobuf::libprotoc>
5.033 
5.033   No target "protobuf::libprotoc"
5.033 Call Stack (most recent call first):
5.033   /usr/local/lib/python3.12/dist-packages/cmake/data/share/cmake-3.31/Modules/ExternalProject.cmake:2234 (_ep_write_log_script)
5.033   /usr/local/lib/python3.12/dist-packages/cmake/data/share/cmake-3.31/Modules/ExternalProject.cmake:2659:EVAL:2 (ExternalProject_Add_Step)
5.033   /usr/local/lib/python3.12/dist-packages/cmake/data/share/cmake-3.31/Modules/ExternalProject.cmake:2659 (cmake_language)
5.033   /usr/local/lib/python3.12/dist-packages/cmake/data/share/cmake-3.31/Modules/ExternalProject.cmake:3044 (_ep_add_configure_command)
5.033   cmake_modules/ThirdpartyToolchain.cmake:4532 (externalproject_add)
5.033   cmake_modules/ThirdpartyToolchain.cmake:208 (build_orc)
5.033   cmake_modules/ThirdpartyToolchain.cmake:304 (build_dependency)
5.033   cmake_modules/ThirdpartyToolchain.cmake:4578 (resolve_dependency)
5.033   CMakeLists.txt:543 (include)
5.033 
5.033 
5.033 CMake Error at /usr/local/lib/python3.12/dist-packages/cmake/data/share/cmake-3.31/Modules/ExternalProject.cmake:1816 (file):
5.033   Error evaluating generator expression:
5.033 
5.033     $<TARGET_FILE:protobuf::libprotoc>
5.033 
5.033   No target "protobuf::libprotoc"
5.033 Call Stack (most recent call first):
5.033   /usr/local/lib/python3.12/dist-packages/cmake/data/share/cmake-3.31/Modules/ExternalProject.cmake:2234 (_ep_write_log_script)
5.033   /usr/local/lib/python3.12/dist-packages/cmake/data/share/cmake-3.31/Modules/ExternalProject.cmake:2659:EVAL:2 (ExternalProject_Add_Step)
5.033   /usr/local/lib/python3.12/dist-packages/cmake/data/share/cmake-3.31/Modules/ExternalProject.cmake:2659 (cmake_language)
5.033   /usr/local/lib/python3.12/dist-packages/cmake/data/share/cmake-3.31/Modules/ExternalProject.cmake:3044 (_ep_add_configure_command)
5.033   cmake_modules/ThirdpartyToolchain.cmake:4532 (externalproject_add)
5.033   cmake_modules/ThirdpartyToolchain.cmake:208 (build_orc)
5.033   cmake_modules/ThirdpartyToolchain.cmake:304 (build_dependency)
5.033   cmake_modules/ThirdpartyToolchain.cmake:4578 (resolve_dependency)
5.033   CMakeLists.txt:543 (include)
5.033 
5.033 
5.247 -- Generating done (0.3s)
5.247 CMake Generate step failed.  Build files cannot be regenerated correctly.
------

 1 warning found (use docker --debug to expand):
 - RedundantTargetPlatform: Setting platform to predefined $TARGETPLATFORM in FROM is redundant as this is the default behavior (line 17)
Dockerfile:23
--------------------
  22 |         
  23 | >>> RUN cd /opt/arrow/cpp && \
  24 | >>>     mkdir build && \
  25 | >>>     cd build && \
  26 | >>>     cmake \
  27 | >>>       -DCMAKE_INSTALL_PREFIX=/usr/local \
  28 | >>> 	 -DARROW_CUDA=ON \
  29 | >>> 	 -DARROW_PYTHON=ON \
  30 | >>> 	 -DARROW_COMPUTE=ON \
  31 | >>> 	 -DARROW_CSV=ON \
  32 | >>> 	 -DARROW_DATASET=ON \
  33 | >>> 	 -DARROW_FILESYSTEM=ON \
  34 | >>> 	 -DARROW_HDFS=ON \
  35 | >>> 	 -DARROW_JSON=ON \
  36 | >>> 	 -DARROW_PARQUET=ON \
  37 | >>> 	 -DARROW_ORC=ON \
  38 | >>> 	 -DARROW_WITH_BZ2=ON \
  39 | >>> 	 -DARROW_WITH_LZ4=ON \
  40 | >>> 	 -DARROW_WITH_SNAPPY=ON \
  41 | >>> 	 -DARROW_WITH_ZLIB=ON \
  42 | >>> 	 -DARROW_WITH_ZSTD=ON \
  43 | >>> 	 ../ && \
  44 | >>>     make -j$(nproc) && \
  45 | >>>     make install
  46 |         
--------------------
ERROR: failed to solve: process "/bin/sh -c cd /opt/arrow/cpp &&     mkdir build &&     cd build &&     cmake       -DCMAKE_INSTALL_PREFIX=/usr/local \t -DARROW_CUDA=ON \t -DARROW_PYTHON=ON \t -DARROW_COMPUTE=ON \t -DARROW_CSV=ON \t -DARROW_DATASET=ON \t -DARROW_FILESYSTEM=ON \t -DARROW_HDFS=ON \t -DARROW_JSON=ON \t -DARROW_PARQUET=ON \t -DARROW_ORC=ON \t -DARROW_WITH_BZ2=ON \t -DARROW_WITH_LZ4=ON \t -DARROW_WITH_SNAPPY=ON \t -DARROW_WITH_ZLIB=ON \t -DARROW_WITH_ZSTD=ON \t ../ &&     make -j$(nproc) &&     make install" did not complete successfully: exit code: 1
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Error: Failed to build image for 01-01-arrow (build/01-01-arrow).
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Build, push or pull failed for build/01-01-arrow. Subsequent dependent builds might fail.
Build process for build/01-01-arrow exited with code 1
Continuing with next build...
Processing numbered directory: build/01-01-numba
Using base image: kairin/001:01-00-build-essential
--------------------------------------------------
