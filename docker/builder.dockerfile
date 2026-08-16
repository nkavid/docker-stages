FROM ubuntu:22.04

RUN apt-get update && apt-get install --no-install-recommends -y \
build-essential=12.9ubuntu3 git=1:2.34.1-1ubuntu1.17 ca-certificates=20260601~22.04.1 libssl-dev=3.0.2-0ubuntu1.25 \
libgmp-dev=2:6.2.1+dfsg-3ubuntu1 libmpfr-dev=4.1.0-3build3 libmpc-dev=1.2.1-2build1 texinfo=6.8-4build1 file=1:5.41-3ubuntu0.1 m4=1.4.18-5ubuntu2 flex=2.6.4-8build2 \
cmake=3.22.1-1ubuntu1.22.04.2 python3-dev=3.10.6-1~22.04.1 ninja-build=1.10.1-1 \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
