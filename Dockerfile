FROM ubuntu:22.04 AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install --no-install-recommends -y \
build-essential=12.9ubuntu3 git=1:2.34.1-1ubuntu1.17 ca-certificates=20260601~22.04.1 curl=7.81.0-1ubuntu1.25 \
bison=2:3.8.2+dfsg-1build1 gawk=1:5.1.0-1ubuntu0.1 gettext=0.21-4ubuntu4 m4=1.4.18-5ubuntu2 flex=2.6.4-8build2 \
texinfo=6.8-4build1 file=1:5.41-3ubuntu0.1 xz-utils=5.2.5-2ubuntu1.1 pkg-config=0.29.2-1ubuntu3 python3=3.10.6-1~22.04.1 \
zlib1g-dev=1:1.2.11.dfsg-2ubuntu9.2 patchelf=0.14.3-1 rsync=3.2.7-0ubuntu0.22.04.7 \
&& rm -rf /var/lib/apt/lists/*

####################################################################################################
# Sysroot: kernel UAPI headers + glibc, built from source so gcc never resolves against the
# container's own /usr/include or /usr/lib.
####################################################################################################

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

RUN make --jobs "$(( $(nproc) - 1 ))" \
|| (find . -name config.log -print -exec cat {} \; && exit 1)

RUN make DESTDIR=/sysroot install

####################################################################################################
# GCC, configured with a relocatable sysroot and in-tree GMP/MPFR/MPC so the installed compiler
# has no dependency on this container once extracted.
####################################################################################################

FROM base AS gcc

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=glibc /sysroot /sysroot

WORKDIR /build/gcc

RUN git clone --branch "releases/gcc-12.5.0" --depth 1 "git://gcc.gnu.org/git/gcc.git" .

RUN ./contrib/download_prerequisites

WORKDIR /build/gcc/build

RUN ../configure \
--disable-multilib \
--disable-multiarch \
--enable-languages=c,c++ \
--disable-nls \
--disable-libvtv \
--disable-libphobos \
--disable-libquadmath \
--disable-libitm \
--with-build-config=bootstrap-lto-lean \
--prefix="/opt/nkavid/gcc/gcc_12.5" \
--with-sysroot=/RELOCATABLE_SYSROOT \
--with-build-sysroot=/sysroot \
|| (cat config.log && exit 1)

# hadolint ignore=SC2016
RUN grep -rl '/RELOCATABLE_SYSROOT' . | xargs sed -i 's|/RELOCATABLE_SYSROOT|$(exec_prefix)/sysroot|g'

RUN mkdir -p "/opt/nkavid/gcc/gcc_12.5/sysroot"

RUN cp -a /sysroot/. "/opt/nkavid/gcc/gcc_12.5/sysroot/"

RUN make -j"$(( $(nproc) - 1 ))" all-gcc \
|| (find . -name config.log -print -exec cat {} \; && exit 1)

RUN make install-gcc

ENV PATH="/opt/nkavid/gcc/gcc_12.5/bin:${PATH}"

RUN make -j"$(( $(nproc) - 1 ))" profiledbootstrap \
|| (find . -name config.log -print -exec cat {} \; && exit 1)

RUN make install-strip

# hadolint ignore=SC2016
RUN set -o errexit -o nounset \
&& while IFS= read -r -d '' shared_object; do \
if file --brief "${shared_object}" | grep --quiet '^ELF'; then \
patchelf --set-rpath '$ORIGIN' "${shared_object}"; \
fi \
done < <(find "/opt/nkavid/gcc/gcc_12.5" -name '*.so*' -type f -print0)

FROM ubuntu:22.04

RUN apt-get update && apt-get install --no-install-recommends -y \
binutils=2.38-4ubuntu2.12 \
&& rm -rf /var/lib/apt/lists/*

COPY --from=gcc "/opt/nkavid/gcc/gcc_12.5" "/opt/nkavid/gcc/gcc_12.5"
ENV PATH="/opt/nkavid/gcc/gcc_12.5/bin:${PATH}"

WORKDIR /workspace
