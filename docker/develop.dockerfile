FROM ubuntu:22.04

RUN apt-get update && apt-get install --no-install-recommends -y \
binutils=2.38-4ubuntu2.12 libc6-dev=2.35-0ubuntu3.13 libmpfr-dev=4.1.0-3build3 libmpc-dev=1.2.1-2build1 \
&& rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/nkavid/gcc/gcc_12.5/bin:${PATH}"
ENV PATH="/opt/nkavid/cmake/cmake_3.29/bin:${PATH}"
