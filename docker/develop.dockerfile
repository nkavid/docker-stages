FROM ubuntu:22.04

RUN apt-get update && apt-get install --no-install-recommends -y \
binutils libc-dev libmpfr-dev libmpc-dev \
&& rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/nkavid/gcc/gcc_12.3/bin:${PATH}"
ENV PATH="/opt/nkavid/cmake/cmake_3.29/bin:${PATH}"
