#!/bin/bash

BASENAME="$(basename "$0")"
RED="\x1B[31m"
RESET="\x1B[0m"

function error()
{
	echo -e "${RED}${BASENAME}::[ERROR]:${RESET} $1"
}

if [[ $1 == "lint" ]]; then
	set -x
	for dockerfile in docker/*.dockerfile; do
		docker run --rm -i -v "${PWD}/.hadolint.yaml:/.hadolint.yaml" hadolint/hadolint <"${dockerfile}"
	done
	{ set +x; } &>/dev/null
fi

if [[ $1 == "stages" ]]; then
	if [[ $2 == "image" ]]; then
		SYSROOT_IMAGE="nkavid/sysroot:0.0.1"
		docker build --tag "${SYSROOT_IMAGE}" --file "docker/sysroot.dockerfile" . \
|| { error "docker buildx history logs"; exit 1; }

		for GCC_VERSION in "12.5.0" "13.4.0"; do
			docker build --build-arg "GCC_VERSION=${GCC_VERSION}" \
--tag "nkavid/gcc:${GCC_VERSION}" --file "docker/gcc.dockerfile" . \
|| { error "docker buildx history logs"; exit 1; }
		done

		LLVM_VERSION="22.1.8"
		docker build --build-arg "LLVM_VERSION=${LLVM_VERSION}" \
--tag "nkavid/llvm:${LLVM_VERSION}" --file "docker/llvm.dockerfile" . \
|| { error "docker buildx history logs"; exit 1; }
	fi

	if [[ $2 == "check" ]]; then
		docker run --rm \
--mount "type=image,source=nkavid/gcc:12.5.0,target=/opt,readonly,image-subpath=opt" \
ubuntu:22.04 "/opt/nkavid/gcc/gcc_12.5.0/bin/gcc" --version \
|| { error "gcc 12.5.0 toolchain not usable from mounted artifact"; exit 1; }
	fi
fi
