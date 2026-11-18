ARG KERNEL_VERSION=5.15
ARG GLIBC_VERSION=2.35
ARG TARGET_CPU=x86_64
ARG TARGET_OS=linux
ARG KERNEL_ARCH=x86_64
ARG SYSROOT_JSON=usr/share/nkavid/sysroot.json

FROM nkavid/shared_base_ubuntu_22.04 AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

FROM base AS kernel_headers

ARG KERNEL_VERSION
ARG KERNEL_ARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /build/linux

RUN curl --fail --location "https://github.com/torvalds/linux/archive/refs/tags/v${KERNEL_VERSION}.tar.gz" \
| tar --gzip --extract --strip-components=1 --file -

RUN make headers_install ARCH="${KERNEL_ARCH}" INSTALL_HDR_PATH=/sysroot/usr

FROM base AS glibc

ARG GLIBC_VERSION
ARG KERNEL_VERSION
ARG TARGET_CPU
ARG TARGET_OS
ARG SYSROOT_JSON

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN test "$(uname -m)" = "${TARGET_CPU}" \
&& test "$(uname -s | tr '[:upper:]' '[:lower:]')" = "${TARGET_OS}"

COPY --from=kernel_headers /sysroot /sysroot

WORKDIR /build/glibc

RUN curl --fail --location "https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.xz" \
| tar --xz --extract --strip-components=1 --file -

WORKDIR /build/glibc/build

RUN ../configure \
--prefix=/usr \
--with-headers=/sysroot/usr/include \
--enable-kernel=${KERNEL_VERSION} \
--disable-werror \
libc_cv_slibdir=/lib \
|| (cat config.log && exit 1)

RUN make --jobs $(( $(nproc) - 1 )) \
|| (find . -name config.log -print -exec cat {} \; && exit 1)

RUN make DESTDIR=/sysroot install

RUN grep --recursive --files-with-matches --binary-files=without-match '^GROUP' /sysroot/usr/lib \
| xargs sed --in-place --regexp-extended '/^GROUP/s@([( ])/@\1=/@g' \
&& ! grep --recursive --binary-files=without-match --extended-regexp '^GROUP.*[( ]/' /sysroot/usr/lib

RUN mkdir -p "$(dirname "/sysroot/${SYSROOT_JSON}")" \
&& jq --null-input \
--arg cpu "${TARGET_CPU}" \
--arg os "${TARGET_OS}" \
--arg libc "glibc-${GLIBC_VERSION}" \
'{abi_libc_version: $libc, host_cpu: $cpu, host_os: $os, host_system_name: "\($os)_\($cpu)", target_cpu: $cpu, target_libc: $libc, target_os: $os}' \
>"/sysroot/${SYSROOT_JSON}"

FROM scratch AS sysroot

COPY --from=glibc /sysroot /sysroot
