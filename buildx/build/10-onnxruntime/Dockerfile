#---
# name: onnxruntime
# group: ml
# config: config.py
# depends: [cuda, cudnn, tensorrt, cmake, python, numpy, onnx]
# test: test.py
# notes: the `onnxruntime-gpu` wheel that's built is saved in the container under `/opt`
#---
# Hardcoded base image from the previous stage
FROM kairin/001:10-onnx

ARG ONNXRUNTIME_VERSION \
    ONNXRUNTIME_BRANCH \
    ONNXRUNTIME_FLAGS \
    FORCE_BUILD=off

COPY install.sh build.sh /tmp/onnxruntime/

RUN /tmp/onnxruntime/install.sh || /tmp/onnxruntime/build.sh
