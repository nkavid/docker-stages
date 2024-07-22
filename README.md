# docker-stages

Docker images can be huge unless care is taken to remove, or avoid, unnecessary clutter. Affects storage space and processing times.

Seems best practice is to use a "builder" stages.

## Goal

Minimal "develop" and "deployment" images for [my sandbox repository](https://github.com/nkavid/sandbox-gfx). GCC and LLVM toolchains working together with static and dynamic analysis available. Everything in "develop" images is used in CI pipeline. "Applications" run in minimal "deployment" images without any tooling dependencies.

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
