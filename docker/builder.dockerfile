FROM ubuntu:22.04

RUN apt-get update && apt-get install --no-install-recommends -y \
build-essential git ca-certificates libssl-dev \
libgmp-dev libmpfr-dev libmpc-dev texinfo file m4 flex \
cmake python3-dev ninja-build \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
