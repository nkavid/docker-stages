FROM ubuntu:22.04 as BUILD

RUN apt-get update && apt-get install --no-install-recommends -y \
build-essential git ca-certificates libssl-dev \
libgmp-dev libmpfr-dev libmpc-dev texinfo file m4 flex \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /build-workspace

RUN git clone --branch "releases/gcc-12.3.0" --depth 1 "git://gcc.gnu.org/git/gcc.git" \
&& cd gcc \
&& ./configure \
--disable-multilib \
--enable-languages=c,c++ \
--disable-nls \
--disable-libvtv \
--disable-libphobos \
--disable-libquadmath \
--disable-libitm \
--quiet \
--prefix="/opt/nkavid/gcc/gcc_12.3" \
&& make --quiet -j$(( $(nproc) + 1 )) \
&& make install-strip \
&& rm -rf ./*

RUN git clone --branch "v3.29.3" --depth 1 "https://github.com/Kitware/CMake.git" \
&& cd CMake \
&& ./configure \
--parallel=$(( $(nproc) + 1 )) \
--prefix="/opt/nkavid/cmake/cmake_3.29" \
&& make --quiet -j$(( $(nproc) + 1 )) \
&& make install \
&& rm -rf ./*

FROM ubuntu:22.04

COPY --from=BUILD "/opt/nkavid" "/opt/nkavid"
ENV PATH="/opt/nkavid/gcc/gcc_12.3/bin:/opt/nkavid/cmake/cmake_3.29/bin:${PATH}"

RUN apt-get update && apt-get install --no-install-recommends -y \
binutils libc-dev libmpfr-dev libmpc-dev \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
