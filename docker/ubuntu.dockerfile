FROM ubuntu:22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install --no-install-recommends -y \
bison=2:3.8.2+dfsg-1ubuntu0.22.04.1 build-essential=12.9ubuntu3 ca-certificates=20260816ubuntu0.22.04.2 \
cmake=3.22.1-1ubuntu1.22.04.2 curl=7.81.0-1ubuntu1.30 file=1:5.41-3ubuntu0.1 flex=2.6.4-8build2 \
gawk=1:5.1.0-1ubuntu0.2 gettext=0.21-4ubuntu4 git=1:2.34.1-1ubuntu1.18 jq=1.6-2.1ubuntu3.2 m4=1.4.18-5ubuntu2 \
ninja-build=1.10.1-1 patchelf=0.14.3-1 pkg-config=0.29.2-1ubuntu3 python3=3.10.6-1~22.04.1 \
rsync=3.2.7-0ubuntu0.22.04.7 texinfo=6.8-4build1 xz-utils=5.2.5-2ubuntu1.2 zlib1g-dev=1:1.2.11.dfsg-2ubuntu9.2 \
&& rm -rf /var/lib/apt/lists/*
