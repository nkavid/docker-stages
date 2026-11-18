ARG GCC_VERSION
ARG GCC_TRIPLE=x86_64-pc-linux-gnu
ARG BINUTILS_VERSION=2.44
ARG SYSROOT_JSON=usr/share/nkavid/sysroot.json
ARG TOOLCHAIN_JSON=share/nkavid/toolchain.json

FROM nkavid/shared_base_ubuntu_22.04 AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

FROM nkavid/sysroot:0.0.1 AS sysroot

FROM base AS binutils

ARG GCC_VERSION
ARG BINUTILS_VERSION

ENV GCC_PREFIX="/opt/nkavid/gcc/gcc_${GCC_VERSION}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN test -n "${GCC_VERSION}"

WORKDIR /build/binutils

RUN curl --fail --location "https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz" \
| tar --xz --extract --strip-components=1 --file -

WORKDIR /build/binutils/build

RUN ../configure \
--prefix="${GCC_PREFIX}" \
--with-sysroot="${GCC_PREFIX}/sysroot" \
--disable-nls \
--disable-werror \
--disable-gprofng \
|| (cat config.log && exit 1)

RUN make --jobs $(( $(nproc) - 1 )) \
|| (find . -name config.log -print -exec cat {} \; && exit 1)

RUN make install-strip

FROM base AS gcc

ARG GCC_VERSION
ARG GCC_TRIPLE
ARG SYSROOT_JSON
ARG TOOLCHAIN_JSON

ENV GCC_PREFIX="/opt/nkavid/gcc/gcc_${GCC_VERSION}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=sysroot /sysroot /sysroot
COPY --from=binutils "${GCC_PREFIX}" "${GCC_PREFIX}"

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
--prefix="${GCC_PREFIX}" \
--with-sysroot=/RELOCATABLE_SYSROOT \
--with-build-sysroot=/sysroot \
|| (cat config.log && exit 1)

# hadolint ignore=SC2016
RUN grep -rl '/RELOCATABLE_SYSROOT' . | xargs sed -i 's|/RELOCATABLE_SYSROOT|$(exec_prefix)/sysroot|g'

RUN mkdir -p "${GCC_PREFIX}/sysroot"

RUN cp -a /sysroot/. "${GCC_PREFIX}/sysroot/"

RUN make -j"$(( $(nproc) - 1 ))" all-gcc \
|| (find . -name config.log -print -exec cat {} \; && exit 1)

RUN make install-gcc

ENV PATH="${GCC_PREFIX}/bin:${PATH}"

RUN make -j"$(( $(nproc) - 1 ))" profiledbootstrap \
|| (find . -name config.log -print -exec cat {} \; && exit 1)

RUN make install-strip

RUN test "$("${GCC_PREFIX}/bin/gcc" -dumpfullversion)" = "${GCC_VERSION}" \
&& test "$("${GCC_PREFIX}/bin/gcc" -dumpmachine)" = "${GCC_TRIPLE}"

# hadolint ignore=SC2016
RUN set -o errexit -o nounset -o pipefail \
&& find "${GCC_PREFIX}" -path "${GCC_PREFIX}/sysroot" -prune -o -name '*.so*' -type f -print0 \
| while IFS= read -r -d '' shared_object; do \
if file --brief "${shared_object}" | grep --quiet '^ELF'; then \
patchelf --set-rpath '$ORIGIN' "${shared_object}"; \
fi \
done

RUN mkdir -p "$(dirname "${GCC_PREFIX}/${TOOLCHAIN_JSON}")" \
&& jq \
--arg version "${GCC_VERSION}" \
--arg triple "${GCC_TRIPLE}" \
--arg prefix "${GCC_PREFIX}" \
'. + {abi_version: "gcc", compiler: "gcc", cxx_builtin_include_directories: [\
"include/c++/\($version)", \
"include/c++/\($version)/\($triple)", \
"include/c++/\($version)/backward", \
"lib/gcc/\($triple)/\($version)/include", \
"lib/gcc/\($triple)/\($version)/include-fixed", \
"sysroot/usr/include"], \
install_prefix: $prefix, target_system_name: $triple, \
toolchain_identifier: "gcc_\($version)_\(.target_os)_\(.target_cpu)", version: $version}' \
"${GCC_PREFIX}/sysroot/${SYSROOT_JSON}" \
>"${GCC_PREFIX}/${TOOLCHAIN_JSON}" \
&& jq --raw-output '.cxx_builtin_include_directories[]' "${GCC_PREFIX}/${TOOLCHAIN_JSON}" \
| xargs -I{} test -d "${GCC_PREFIX}/{}"

FROM scratch AS export

ARG GCC_VERSION

ENV GCC_PREFIX="/opt/nkavid/gcc/gcc_${GCC_VERSION}"

COPY --from=gcc "${GCC_PREFIX}" "${GCC_PREFIX}"
