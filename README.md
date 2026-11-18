# docker-stages

Builds relocatable GCC and LLVM toolchain trees in Docker for [sandbox-gfx](https://github.com/nkavid/sandbox-gfx).

Each image `nkavid/<gcc|llvm>:<version>` is `FROM scratch` and holds only `/opt/nkavid/<kind>/<kind>_<version>`. Trees depend on nothing on the host except glibc:

- gcc bundles binutils in the same prefix and finds its sysroot relative to the prefix.
- llvm ships lld and the llvm binutils, links libstdc++/libgcc statically into the tools, and finds its sysroot through `bin/clang.cfg`/`bin/clang++.cfg` (`--sysroot=<CFGDIR>/../sysroot`).

## Usage

```
./run.sh lint
./run.sh latest
./run.sh stages image <gcc|llvm> <version> [--verbose]
./run.sh stages export <gcc|llvm> <version> | all
./run.sh stages check
```

`stages image` writes per-second memory, load and top-process samples to `build/metrics/<tag>.log` and the plain build output to `build/metrics/<tag>.build.log`. `stages export` writes `build/export/<kind>_<version>.tar` and its `.sha256`.

## References

- [toolchains_llvm](https://github.com/bazel-contrib/toolchains_llvm), [gcc-toolchain](https://github.com/f0rmiga/gcc-toolchain)
- [Docker multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [FROM scratch](https://hub.docker.com/_/scratch)
- [The Quest for Minimal Docker Images](https://jpetazzo.github.io/2020/02/01/quest-minimal-docker-images-part-1/)
