#!/bin/bash

if [[ $1 == "lint" ]]; then
	set -x
	for dockerfile in "Dockerfile" docker/*.dockerfile; do
		docker run --rm -i -v "${PWD}/.hadolint.yaml:/.hadolint.yaml" hadolint/hadolint <"${dockerfile}"
	done
	{ set +x; } &>/dev/null
fi

if [[ $1 == "builder" ]]; then
	BUILDER_IMAGE="nkavid/dockerfile-builder:0.0.1"
	if [[ $2 == "image" ]]; then
		docker build --tag "${BUILDER_IMAGE}" --file "docker/builder.dockerfile" . \
|| echo "docker buildx history logs"
	fi

	if [[ $2 == "compile" ]]; then
		CONTAINER_NAME="builder-container"
		docker create --name "${CONTAINER_NAME}" -v "${PWD}:/workspace" -t "${BUILDER_IMAGE}"
		docker start "${CONTAINER_NAME}"

		NUM_JOBS=$(($(nproc) + 1))

		docker exec "${CONTAINER_NAME}" bash -c "\
mkdir -p build/gnu_gcc_12 \
&& cd build/gnu_gcc_12 \
&& ../../thirdparty/gnu_gcc_12/configure \
--disable-multilib \
--enable-languages=c,c++ \
--disable-nls \
--disable-libvtv \
--disable-libphobos \
--disable-libquadmath \
--disable-libitm \
--quiet \
--prefix='/opt/nkavid/gcc/gcc_12.5' \
&& make --quiet -j${NUM_JOBS} \
&& make install-strip"

		docker exec "${CONTAINER_NAME}" bash -c "\
mkdir -p build/Kitware_CMake \
&& cd build/Kitware_CMake \
&& ../../thirdparty/Kitware_CMake/configure \
--parallel=${NUM_JOBS} \
--prefix='/opt/nkavid/cmake/cmake_3.29' \
&& make --quiet -j${NUM_JOBS} \
&& make install"

		docker cp "${CONTAINER_NAME}:/opt" "${PWD}/opt"

		docker kill "${CONTAINER_NAME}" >/dev/null
		docker rm "${CONTAINER_NAME}"
	fi

	if [[ $2 == "llvm-tools" ]]; then
		CONTAINER_NAME="builder-container"
		docker create --name "${CONTAINER_NAME}" -v "${PWD}:/workspace" -t "${BUILDER_IMAGE}"
		docker start "${CONTAINER_NAME}"

		NUM_JOBS=$(($(nproc) + 1))

		docker exec "${CONTAINER_NAME}" bash -c "\
cmake -Sthirdparty/llvm_llvm-project/llvm -Bbuild/llvm-tools \
-DCMAKE_CXX_STANDARD=17 \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_INSTALL_PREFIX=/opt/nkavid/llvm/llvm_17.x \
-DLLVM_TARGETS_TO_BUILD=X86 \
-DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra' \
-DLLVM_EXTERNAL_PROJECTS=iwyu \
-DLLVM_EXTERNAL_IWYU_SOURCE_DIR=thirdparty/include-what-you-use_include-what-you-use \
&& cd build/llvm-tools \
&& make -j${NUM_JOBS} clang-tidy clang-format include-what-you-use"

		docker kill "${CONTAINER_NAME}" >/dev/null
		docker rm "${CONTAINER_NAME}"
	fi

	if [[ $2 == "llvm-bootstrap" ]]; then
		CONTAINER_NAME="builder-container"
		docker create --name "${CONTAINER_NAME}" -v "${PWD}:/workspace" -t "${BUILDER_IMAGE}"
		docker start "${CONTAINER_NAME}"

		NUM_JOBS=$(($(nproc) + 1))

		docker exec "${CONTAINER_NAME}" bash -c "\
git config --global --add safe.directory '*' \
&& cmake -GNinja -Sthirdparty/llvm_llvm-project/llvm -Bbuild/llvm_llvm-project \
-DCMAKE_CXX_STANDARD=17 \
-DCMAKE_BUILD_TYPE=Release \
-DCLANG_ENABLE_BOOTSTRAP=ON \
-DCLANG_BOOTSTRAP_PASSTHROUGH='CMAKE_INSTALL_PREFIX;CMAKE_VERBOSE_MAKEFILE;CMAKE_BUILD_TYPE' \
-DBOOTSTRAP_LLVM_ENABLE_LTO=ON \
-DBOOTSTRAP_LLVM_USE_LINKER=gold \
-DBOOTSTRAP_LLVM_INSTALL_TOOLCHAIN_ONLY=ON \
-DCMAKE_INSTALL_PREFIX=/opt/nkavid/llvm/llvm_17.x \
-DLLVM_TARGETS_TO_BUILD='X86;NVPTX' \
-DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra;lld' \
-DLLVM_ENABLE_RUNTIMES='libcxx;libcxxabi' \
-DLLVM_EXTERNAL_PROJECTS=iwyu \
-DLLVM_EXTERNAL_IWYU_SOURCE_DIR=thirdparty/include-what-you-use_include-what-you-use \
&& cd build/llvm_llvm-project \
&& ninja -j16 stage2-install"

		docker cp "${CONTAINER_NAME}:/opt/nkavid/llvm" "${PWD}/opt/nkavid/llvm"

		docker kill "${CONTAINER_NAME}" >/dev/null
		docker rm "${CONTAINER_NAME}"
	fi
fi

if [[ $1 == "develop" ]]; then
	DEVELOP_IMAGE="nkavid/dockerfile-develop:0.0.1"
	if [[ $2 == "image" ]]; then
		docker build --tag "${DEVELOP_IMAGE}" --file "docker/develop.dockerfile" . \
|| echo "docker buildx history logs"
	fi

	if [[ $2 == "demo" ]]; then
		CONTAINER_NAME="develop-container"
		docker create --name "${CONTAINER_NAME}" -v "${PWD}/opt/nkavid:/opt/nkavid" -t "${DEVELOP_IMAGE}"
		docker start "${CONTAINER_NAME}"
		docker exec "${CONTAINER_NAME}" bash -c "gcc --version"
		docker exec "${CONTAINER_NAME}" bash -c "cmake --version"
		docker kill "${CONTAINER_NAME}" >/dev/null
		docker rm "${CONTAINER_NAME}"
	fi
fi

if [[ $1 == "top-dockerfile" ]]; then
	TOP_IMAGE="nkavid/dockerfile-top:0.0.1"
	if [[ $2 == "image" ]]; then
		docker build --tag "${TOP_IMAGE}" --file "Dockerfile" . \
|| echo "docker buildx history logs"
	fi
fi

if [[ $1 == "stages" ]]; then
	if [[ $2 == "image" ]]; then
		SYSROOT_IMAGE="nkavid/dockerfile-sysroot:0.0.1"
		docker build --tag "${SYSROOT_IMAGE}" --file "docker/sysroot.dockerfile" . \
|| echo "docker buildx history logs"

		GCC_IMAGE="nkavid/dockerfile-gcc:0.0.1"
		docker build --tag "${GCC_IMAGE}" --file "docker/gcc.dockerfile" . \
|| echo "docker buildx history logs"

		GCC13_IMAGE="nkavid/dockerfile-gcc13:0.0.1"
		docker build --tag "${GCC13_IMAGE}" --file "docker/gcc13.dockerfile" . \
|| echo "docker buildx history logs"

		LLVM_IMAGE="nkavid/dockerfile-llvm:0.0.1"
		docker build --tag "${LLVM_IMAGE}" --file "docker/llvm.dockerfile" . \
|| echo "docker buildx history logs"
	fi
fi
