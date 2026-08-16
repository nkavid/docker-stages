# docker-stages

Docker images can be huge unless care is taken to remove, or avoid, unnecessary clutter. Affects storage space and processing times.

Seems best practice is to use a "builder" stages.

## Goal

Minimal "develop" and "deployment" images for [my sandbox repository](https://github.com/nkavid/sandbox-gfx). A single toolchain — either GCC *or* LLVM/Clang, not both together — with static and dynamic analysis available. Whether the LLVM clang-tools (clang-tidy, clang-format, include-what-you-use) are used alongside a GCC or a Clang toolchain is a separate concern. Everything in "develop" images is used in CI pipeline. "Applications" run in minimal "deployment" images without any tooling dependencies.

## Toolchain distribution

The `stages` images double as distribution artifacts for the toolchain trees under `/opt/nkavid` — consumers extract the tree and run the tools on the host, e.g. as a Bazel `cc_toolchain`; nothing builds inside the container. Both trees are self-contained and relocatable with no host dependency beyond glibc: `gcc_12.5` bundles binutils in the same prefix (so `as`/`ld` resolve from the tree via GCC's tooldir search) and finds its sysroot relative to the install prefix; `llvm_22.1` ships lld and the llvm binutils, links libstdc++/libgcc statically into the tools, and resolves its bundled sysroot through `bin/clang.cfg`/`bin/clang++.cfg` driver config files (`--sysroot=<CFGDIR>/../sysroot`) instead of a baked absolute `DEFAULT_SYSROOT`. `docker build --file docker/<name>.dockerfile --target export --output <dir> .` writes the bare tree without the ubuntu base — the artifact to tar and pin with a sha256. Consumption plan lives in the hello-toolchain sandbox repo's README.

## TODOs

 - [ ] Rerunning building an image from scratch when figuring out all dependencies needed is annoying and wasteful. Need simpler way of doing that and once finished only then do dockerfile optimization.

 - [ ] Structure `run.sh` for better overview

 - [ ] Replace "ubuntu" base with something smaller

 - [ ] Alpine?

 - [ ] Docker BuildKit?

## References

Distribute host sysroot you need. Support for other environments through cross-compilation. Bazel workspace examples [toolchains_llvm](https://github.com/bazel-contrib/toolchains_llvm) and [gcc-toolchain](https://github.com/f0rmiga/gcc-toolchain).

[Docker docs: multi-stage](https://docs.docker.com/build/building/multi-stage/).

[FROM scratch](https://hub.docker.com/_/scratch).

[The Quest for Minimal Docker Images](https://jpetazzo.github.io/2020/02/01/quest-minimal-docker-images-part-1/).
