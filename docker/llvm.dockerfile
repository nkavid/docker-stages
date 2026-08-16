FROM ubuntu:22.04 AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install --no-install-recommends -y \
build-essential=12.9ubuntu3 ca-certificates=20260601~22.04.1 curl=7.81.0-1ubuntu1.25 git=1:2.34.1-1ubuntu1.17 \
cmake=3.22.1-1ubuntu1.22.04.2 ninja-build=1.10.1-1 python3=3.10.6-1~22.04.1 zlib1g-dev=1:1.2.11.dfsg-2ubuntu9.2 \
patchelf=0.14.3-1 file=1:5.41-3ubuntu0.1 \
&& rm -rf /var/lib/apt/lists/*

FROM base AS source

ARG LLVM_VERSION

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN test -n "${LLVM_VERSION}"

WORKDIR /src/llvm-project

RUN git clone --branch "llvmorg-${LLVM_VERSION}" --depth 1 "https://github.com/llvm/llvm-project.git" . \
&& git tag --points-at HEAD | grep --line-regexp --quiet "llvmorg-${LLVM_VERSION}"

FROM nkavid/sysroot:0.0.1 AS sysroot

FROM base AS stage1

COPY --from=source /src/llvm-project /src/llvm-project

RUN cmake -GNinja -S /src/llvm-project/llvm -B /build/stage1 \
-DCMAKE_BUILD_TYPE=Release \
-DLLVM_ENABLE_PROJECTS="clang;lld;bolt" \
-DLLVM_TARGETS_TO_BUILD="X86" \
-DLLVM_PARALLEL_COMPILE_JOBS=8 \
-DLLVM_PARALLEL_LINK_JOBS=2 \
-DCMAKE_INSTALL_PREFIX=/opt/stage1

RUN ninja -C /build/stage1 install

FROM base AS runtimes

ARG LLVM_VERSION

COPY --from=source /src/llvm-project /src/llvm-project
COPY --from=stage1 /opt/stage1 /opt/stage1
COPY --from=sysroot /sysroot /sysroot

RUN LLVM_MAJOR="${LLVM_VERSION%%.*}" \
&& cmake -GNinja -S /src/llvm-project/runtimes -B /build/compiler-rt \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_C_COMPILER=/opt/stage1/bin/clang \
-DCMAKE_CXX_COMPILER=/opt/stage1/bin/clang++ \
-DCMAKE_ASM_COMPILER=/opt/stage1/bin/clang \
-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
-DLLVM_ENABLE_RUNTIMES="compiler-rt" \
-DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
-DCMAKE_C_FLAGS="--sysroot=/sysroot" \
-DCMAKE_CXX_FLAGS="--sysroot=/sysroot" \
-DCOMPILER_RT_BUILD_CRT=ON \
-DCOMPILER_RT_BUILD_SANITIZERS=OFF \
-DCOMPILER_RT_BUILD_XRAY=OFF \
-DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
-DCOMPILER_RT_BUILD_MEMPROF=OFF \
-DCOMPILER_RT_BUILD_ORC=OFF \
-DCOMPILER_RT_BUILD_PROFILE=ON \
"-DCOMPILER_RT_INSTALL_PATH=/opt/stage1/lib/clang/${LLVM_MAJOR}" \
-DCMAKE_INSTALL_PREFIX=/opt/stage1

RUN LLVM_MAJOR="${LLVM_VERSION%%.*}" \
&& ninja -C /build/compiler-rt install \
&& mkdir -p "/opt/nkavid/llvm/llvm_${LLVM_VERSION}/lib/clang/${LLVM_MAJOR}/lib" \
&& cp -a "/opt/stage1/lib/clang/${LLVM_MAJOR}/lib/." "/opt/nkavid/llvm/llvm_${LLVM_VERSION}/lib/clang/${LLVM_MAJOR}/lib/"

RUN cmake -GNinja -S /src/llvm-project/runtimes -B /build/runtimes \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_C_COMPILER=/opt/stage1/bin/clang \
-DCMAKE_CXX_COMPILER=/opt/stage1/bin/clang++ \
-DCMAKE_ASM_COMPILER=/opt/stage1/bin/clang \
-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
-DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx" \
-DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
-DCMAKE_C_FLAGS="--sysroot=/sysroot" \
-DCMAKE_CXX_FLAGS="--sysroot=/sysroot" \
-DCMAKE_EXE_LINKER_FLAGS="--sysroot=/sysroot -fuse-ld=lld --rtlib=compiler-rt --unwindlib=none" \
-DCMAKE_SHARED_LINKER_FLAGS="--sysroot=/sysroot -fuse-ld=lld --rtlib=compiler-rt --unwindlib=none" \
-DLIBUNWIND_USE_COMPILER_RT=ON \
-DLIBCXX_CXX_ABI=libcxxabi \
-DLIBCXX_USE_COMPILER_RT=ON \
-DLIBCXX_HAS_ATOMIC_LIB=OFF \
-DLIBCXXABI_USE_COMPILER_RT=ON \
-DLIBCXXABI_USE_LLVM_UNWINDER=ON \
-DCMAKE_INSTALL_PREFIX=/opt/nkavid/llvm/llvm_${LLVM_VERSION}

RUN ninja -C /build/runtimes install

FROM base AS instrumented

COPY --from=source /src/llvm-project /src/llvm-project
COPY --from=stage1 /opt/stage1 /opt/stage1
COPY --from=runtimes /opt/stage1/lib/clang /opt/stage1/lib/clang

RUN cmake -GNinja -S /src/llvm-project/llvm -B /build/instrumented \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_C_COMPILER=/opt/stage1/bin/clang \
-DCMAKE_CXX_COMPILER=/opt/stage1/bin/clang++ \
-DLLVM_ENABLE_PROJECTS="clang" \
-DLLVM_TARGETS_TO_BUILD="X86" \
-DLLVM_BUILD_INSTRUMENTED=IR \
-DLLVM_USE_LINKER=lld \
-DLLVM_PARALLEL_COMPILE_JOBS=8 \
-DLLVM_PARALLEL_LINK_JOBS=2

RUN ninja -C /build/instrumented clang

RUN cmake -GNinja -S /src/llvm-project/llvm -B /build/train \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_C_COMPILER=/build/instrumented/bin/clang \
-DCMAKE_CXX_COMPILER=/build/instrumented/bin/clang++ \
-DLLVM_ENABLE_PROJECTS="clang" \
-DLLVM_TARGETS_TO_BUILD="X86"

RUN ninja -C /build/train LLVMSupport LLVMCore clangBasic clangLex clangParse

RUN mkdir -p /profiles \
&& /opt/stage1/bin/llvm-profdata merge \
-output=/profiles/clang.profdata \
/build/instrumented/profiles/*.profraw

FROM base AS llvm

ARG LLVM_VERSION

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=source /src/llvm-project /src/llvm-project
COPY --from=stage1 /opt/stage1 /opt/stage1
COPY --from=runtimes /opt/nkavid/llvm/llvm_${LLVM_VERSION} /opt/nkavid/llvm/llvm_${LLVM_VERSION}
COPY --from=sysroot /sysroot /opt/nkavid/llvm/llvm_${LLVM_VERSION}/sysroot
COPY --from=instrumented /profiles/clang.profdata /profiles/clang.profdata

RUN cmake -GNinja -S /src/llvm-project/llvm -B /build/final \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_C_COMPILER=/opt/stage1/bin/clang \
-DCMAKE_CXX_COMPILER=/opt/stage1/bin/clang++ \
-DLLVM_ENABLE_LTO=Thin \
-DLLVM_USE_LINKER=lld \
-DLLVM_PROFDATA_FILE=/profiles/clang.profdata \
-DCMAKE_EXE_LINKER_FLAGS="-Wl,--emit-relocs -static-libgcc" \
-DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld" \
-DLLVM_TARGETS_TO_BUILD="X86;NVPTX" \
-DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
-DLLVM_STATIC_LINK_CXX_STDLIB=ON \
-DLLVM_ENABLE_PIC=OFF \
-DLLVM_ENABLE_ZLIB=FORCE_ON \
-DZLIB_LIBRARY=/usr/lib/x86_64-linux-gnu/libz.a \
-DCLANG_DEFAULT_LINKER=lld \
-DCLANG_DEFAULT_CXX_STDLIB=libc++ \
-DCLANG_DEFAULT_RTLIB=compiler-rt \
-DCLANG_DEFAULT_UNWINDLIB=libunwind \
-DLLVM_PARALLEL_COMPILE_JOBS=8 \
-DLLVM_PARALLEL_LINK_JOBS=2 \
-DCMAKE_INSTALL_PREFIX=/opt/nkavid/llvm/llvm_${LLVM_VERSION}

RUN ninja -C /build/final install

RUN printf -- '--sysroot=<CFGDIR>/../sysroot\n' \
| tee /opt/nkavid/llvm/llvm_${LLVM_VERSION}/bin/clang.cfg \
>/opt/nkavid/llvm/llvm_${LLVM_VERSION}/bin/clang++.cfg

RUN LLVM_MAJOR="${LLVM_VERSION%%.*}" \
&& mkdir -p /profiles/bolt \
&& /opt/stage1/bin/llvm-bolt "/opt/nkavid/llvm/llvm_${LLVM_VERSION}/bin/clang-${LLVM_MAJOR}" \
-instrument \
-o "/opt/nkavid/llvm/llvm_${LLVM_VERSION}/bin/clang-${LLVM_MAJOR}-instrumented" \
--instrumentation-file=/profiles/bolt/prof.fdata \
--instrumentation-file-append-pid

RUN LLVM_MAJOR="${LLVM_VERSION%%.*}" \
&& printf '%s\n' \
'#include <algorithm>' \
'#include <map>' \
'#include <memory>' \
'#include <numeric>' \
'#include <regex>' \
'#include <string>' \
'#include <vector>' \
'int main(int argc, char** argv) {' \
'  std::vector<std::string> args(argv, argv + argc);' \
'  std::map<std::string, std::unique_ptr<std::regex>> patterns;' \
'  for (auto& arg : args) patterns[arg] = std::make_unique<std::regex>(arg);' \
'  std::vector<long> values(1u << 16u);' \
'  std::iota(values.begin(), values.end(), 0L);' \
'  std::sort(values.begin(), values.end(), std::greater<>());' \
'  return static_cast<int>(std::accumulate(values.begin(), values.end(), 0L) % 128);' \
'}' > /tmp/train.cpp \
&& for opt_level in O0 O1 O2 O3; do \
"/opt/nkavid/llvm/llvm_${LLVM_VERSION}/bin/clang-${LLVM_MAJOR}-instrumented" \
--config="/opt/nkavid/llvm/llvm_${LLVM_VERSION}/bin/clang++.cfg" \
--driver-mode=g++ "-${opt_level}" -std=c++20 -c /tmp/train.cpp -o /tmp/train.o; \
done \
&& /opt/stage1/bin/merge-fdata /profiles/bolt/prof.fdata* > /profiles/clang-bolt.fdata

RUN LLVM_MAJOR="${LLVM_VERSION%%.*}" \
&& /opt/stage1/bin/llvm-bolt "/opt/nkavid/llvm/llvm_${LLVM_VERSION}/bin/clang-${LLVM_MAJOR}" \
-o "/opt/nkavid/llvm/llvm_${LLVM_VERSION}/bin/clang-${LLVM_MAJOR}-bolt" \
-data=/profiles/clang-bolt.fdata \
-reorder-blocks=ext-tsp \
-reorder-functions=cdsort \
-split-functions \
-split-all-cold \
-split-eh \
-dyno-stats \
&& mv "/opt/nkavid/llvm/llvm_${LLVM_VERSION}/bin/clang-${LLVM_MAJOR}-bolt" "/opt/nkavid/llvm/llvm_${LLVM_VERSION}/bin/clang-${LLVM_MAJOR}" \
&& rm "/opt/nkavid/llvm/llvm_${LLVM_VERSION}/bin/clang-${LLVM_MAJOR}-instrumented"

# hadolint ignore=SC2016
RUN set -o errexit -o nounset \
&& while IFS= read -r -d '' shared_object; do \
if file --brief "${shared_object}" | grep --quiet '^ELF'; then \
patchelf --set-rpath '$ORIGIN' "${shared_object}"; \
fi \
done < <(find "/opt/nkavid/llvm/llvm_${LLVM_VERSION}" -path "/opt/nkavid/llvm/llvm_${LLVM_VERSION}/sysroot" -prune -o -name '*.so*' -type f -print0)

RUN set -o errexit -o nounset \
&& LLVM_MAJOR="${LLVM_VERSION%%.*}" \
&& while IFS= read -r -d '' binary; do \
if [[ "$(basename "${binary}")" != "clang-${LLVM_MAJOR}" ]] && file --brief "${binary}" | grep --quiet '^ELF'; then \
/opt/stage1/bin/llvm-strip "${binary}"; \
fi \
done < <(find "/opt/nkavid/llvm/llvm_${LLVM_VERSION}/bin" -type f -print0)

FROM scratch AS export

ARG LLVM_VERSION

COPY --from=llvm "/opt/nkavid/llvm/llvm_${LLVM_VERSION}" "/opt/nkavid/llvm/llvm_${LLVM_VERSION}"
