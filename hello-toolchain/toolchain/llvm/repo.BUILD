load("@hello_toolchain//toolchain/llvm:cc_toolchain_config.bzl", "cc_toolchain_config")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "clang",
    srcs = [
        "bin/clang",
        "bin/clang++",
        "bin/clang-cpp",
    ],
)

filegroup(
    name = "include",
    srcs = glob([
        "include/c++/**",
        "include/*/c++/**",
        "lib/clang/*/include/**",
        "sysroot/usr/include/**",
    ]),
)

filegroup(
    name = "lib",
    srcs = glob([
        "lib/clang/*/lib/**",
        "lib/*/libunwind.so",
        "sysroot/lib/*",
        "sysroot/usr/lib/*",
    ]),
)

filegroup(
    name = "static_runtime",
    srcs = [
        "lib/x86_64-unknown-linux-gnu/libc++.a",
        "lib/x86_64-unknown-linux-gnu/libc++abi.a",
        "lib/x86_64-unknown-linux-gnu/libunwind.a",
    ],
)

filegroup(
    name = "dynamic_runtime",
    srcs = [
        "lib/x86_64-unknown-linux-gnu/libc++.so.1",
        "lib/x86_64-unknown-linux-gnu/libc++abi.so.1",
        "lib/x86_64-unknown-linux-gnu/libunwind.so.1",
    ],
)

filegroup(
    name = "ld",
    srcs = [
        "bin/ld.lld",
        "bin/lld",
    ],
)

filegroup(
    name = "ar",
    srcs = ["bin/llvm-ar"],
)

filegroup(
    name = "objcopy",
    srcs = ["bin/llvm-objcopy"],
)

filegroup(
    name = "strip",
    srcs = [
        "bin/llvm-objcopy",
        "bin/llvm-strip",
    ],
)

filegroup(
    name = "dwp",
    srcs = ["bin/llvm-dwp"],
)

filegroup(
    name = "compiler_files",
    srcs = [
        ":clang",
        ":include",
    ],
)

filegroup(
    name = "linker_files",
    srcs = [
        ":ar",
        ":clang",
        ":ld",
        ":lib",
    ],
)

filegroup(
    name = "all_files",
    srcs = [
        ":compiler_files",
        ":dwp",
        ":linker_files",
        ":objcopy",
        ":strip",
    ],
)

cc_toolchain_config(name = "config")

cc_toolchain(
    name = "cc_toolchain",
    all_files = ":all_files",
    ar_files = ":ar",
    as_files = ":clang",
    compiler_files = ":compiler_files",
    dwp_files = ":dwp",
    dynamic_runtime_lib = ":dynamic_runtime",
    linker_files = ":linker_files",
    objcopy_files = ":objcopy",
    static_runtime_lib = ":static_runtime",
    strip_files = ":strip",
    supports_param_files = 1,
    toolchain_config = ":config",
)
