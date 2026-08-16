FROM ubuntu:22.04 AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install --no-install-recommends -y \
build-essential=12.9ubuntu3 git=1:2.34.1-1ubuntu1.17 ca-certificates=20260601~22.04.1 curl=7.81.0-1ubuntu1.25 \
bison=2:3.8.2+dfsg-1build1 gawk=1:5.1.0-1ubuntu0.2 gettext=0.21-4ubuntu4 m4=1.4.18-5ubuntu2 flex=2.6.4-8build2 \
texinfo=6.8-4build1 file=1:5.41-3ubuntu0.1 xz-utils=5.2.5-2ubuntu1.1 pkg-config=0.29.2-1ubuntu3 python3=3.10.6-1~22.04.1 \
zlib1g-dev=1:1.2.11.dfsg-2ubuntu9.2 patchelf=0.14.3-1 rsync=3.2.7-0ubuntu0.22.04.7 \
&& rm -rf /var/lib/apt/lists/*

FROM nkavid/sysroot:0.0.1 AS sysroot

FROM base AS binutils

ARG GCC_VERSION

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN test -n "${GCC_VERSION}"

WORKDIR /build/binutils

RUN curl --fail --location "https://ftp.gnu.org/gnu/binutils/binutils-2.44.tar.xz" \
| tar --xz --extract --strip-components=1 --file -

WORKDIR /build/binutils/build

RUN ../configure \
--prefix="/opt/nkavid/gcc/gcc_${GCC_VERSION}" \
--with-sysroot="/opt/nkavid/gcc/gcc_${GCC_VERSION}/sysroot" \
--disable-nls \
--disable-werror \
--disable-gprofng \
|| (cat config.log && exit 1)

RUN make --jobs $(( $(nproc) + 1 )) \
|| (find . -name config.log -print -exec cat {} \; && exit 1)

RUN make install-strip

FROM base AS gcc

ARG GCC_VERSION

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=sysroot /sysroot /sysroot
COPY --from=binutils "/opt/nkavid/gcc/gcc_${GCC_VERSION}" "/opt/nkavid/gcc/gcc_${GCC_VERSION}"

WORKDIR /build/gcc

RUN git clone --branch "releases/gcc-${GCC_VERSION}" --depth 1 "https://github.com/gcc-mirror/gcc.git" . \
&& git tag --points-at HEAD | grep --line-regexp --quiet "releases/gcc-${GCC_VERSION}" \
&& test "$(cat gcc/BASE-VER)" = "${GCC_VERSION}"

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
--prefix="/opt/nkavid/gcc/gcc_${GCC_VERSION}" \
--with-sysroot=/RELOCATABLE_SYSROOT \
--with-build-sysroot=/sysroot \
|| (cat config.log && exit 1)

# hadolint ignore=SC2016
RUN grep -rl '/RELOCATABLE_SYSROOT' . | xargs sed -i 's|/RELOCATABLE_SYSROOT|$(exec_prefix)/sysroot|g'

RUN mkdir -p "/opt/nkavid/gcc/gcc_${GCC_VERSION}/sysroot"

RUN cp -a /sysroot/. "/opt/nkavid/gcc/gcc_${GCC_VERSION}/sysroot/"

RUN make -j"$(( $(nproc) - 1 ))" all-gcc \
|| (find . -name config.log -print -exec cat {} \; && exit 1)

RUN make install-gcc

ENV PATH="/opt/nkavid/gcc/gcc_${GCC_VERSION}/bin:${PATH}"

RUN make -j"$(( $(nproc) - 1 ))" profiledbootstrap \
|| (find . -name config.log -print -exec cat {} \; && exit 1)

RUN make install-strip

RUN test "$("/opt/nkavid/gcc/gcc_${GCC_VERSION}/bin/gcc" -dumpfullversion)" = "${GCC_VERSION}"

# hadolint ignore=SC2016
RUN set -o errexit -o nounset -o pipefail \
&& find "/opt/nkavid/gcc/gcc_${GCC_VERSION}" -path "/opt/nkavid/gcc/gcc_${GCC_VERSION}/sysroot" -prune -o -name '*.so*' -type f -print0 \
| while IFS= read -r -d '' shared_object; do \
if file --brief "${shared_object}" | grep --quiet '^ELF'; then \
patchelf --set-rpath '$ORIGIN' "${shared_object}"; \
fi \
done

FROM scratch AS export

ARG GCC_VERSION

COPY --from=gcc "/opt/nkavid/gcc/gcc_${GCC_VERSION}" "/opt/nkavid/gcc/gcc_${GCC_VERSION}"
