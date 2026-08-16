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
		mkdir --parents build

		BASE_IMAGE="debian:13"

		for TOOLCHAIN in "gcc 12.5.0 g++" "gcc 13.4.0 g++" "llvm 22.1.8 clang++"; do
			read -r KIND VERSION COMPILER <<<"${TOOLCHAIN}"
			IMAGE_TAG="nkavid/${KIND}:${VERSION}"
			PREFIX_PATH="/mnt/opt/nkavid/${KIND}/${KIND}_${VERSION}"

			docker run --rm \
--mount "type=image,source=${IMAGE_TAG},target=/mnt,readonly" \
"${BASE_IMAGE}" "${PREFIX_PATH}/bin/${COMPILER}" --version \
|| { error "${KIND} ${VERSION} toolchain not usable"; exit 1; }

			docker run --rm \
--mount "type=image,source=${IMAGE_TAG},target=/mnt,readonly" \
-v "${PWD}/dummy:/dummy:ro" -v "${PWD}/build:/build" \
"${BASE_IMAGE}" "${PREFIX_PATH}/bin/${COMPILER}" /dummy/hello.cpp -o "/build/hello_${KIND}_${VERSION}" \
|| { error "${KIND} ${VERSION} cannot compile dummy/hello.cpp"; exit 1; }
		done
	fi
fi
