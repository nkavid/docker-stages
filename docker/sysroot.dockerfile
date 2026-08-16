FROM ubuntu:22.04 AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install --no-install-recommends -y \
build-essential=12.9ubuntu3 ca-certificates=20260601~22.04.1 curl=7.81.0-1ubuntu1.25 \
bison=2:3.8.2+dfsg-1build1 gawk=1:5.1.0-1ubuntu0.2 gettext=0.21-4ubuntu4 m4=1.4.18-5ubuntu2 flex=2.6.4-8build2 \
texinfo=6.8-4build1 file=1:5.41-3ubuntu0.1 xz-utils=5.2.5-2ubuntu1.1 pkg-config=0.29.2-1ubuntu3 python3=3.10.6-1~22.04.1 \
rsync=3.2.7-0ubuntu0.22.04.7 \
&& rm -rf /var/lib/apt/lists/*

FROM base AS kernel_headers

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /build/linux

RUN curl --fail --location "https://github.com/torvalds/linux/archive/refs/tags/v5.15.tar.gz" \
| tar --gzip --extract --strip-components=1 --file -

RUN make headers_install ARCH=x86_64 INSTALL_HDR_PATH=/sysroot/usr

FROM base AS glibc

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=kernel_headers /sysroot /sysroot

WORKDIR /build/glibc

RUN curl --fail --location "https://ftp.gnu.org/gnu/glibc/glibc-2.35.tar.xz" \
| tar --xz --extract --strip-components=1 --file -

WORKDIR /build/glibc/build

RUN ../configure \
--prefix=/usr \
--with-headers=/sysroot/usr/include \
--enable-kernel=5.15 \
--disable-werror \
libc_cv_slibdir=/lib \
|| (cat config.log && exit 1)

RUN make --jobs $(( $(nproc) + 1 )) \
|| (find . -name config.log -print -exec cat {} \; && exit 1)

RUN make DESTDIR=/sysroot install

FROM scratch AS sysroot

COPY --from=glibc /sysroot /sysroot
