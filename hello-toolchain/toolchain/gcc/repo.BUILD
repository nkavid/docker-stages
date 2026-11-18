load("@hello_toolchain//toolchain/gcc:cc_toolchain_config.bzl", "cc_toolchain_config")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "gcc",
    srcs = [
        "bin/cpp",
        "bin/g++",
        "bin/gcc",
    ] + glob([
        "libexec/gcc/*/*/cc1",
        "libexec/gcc/*/*/cc1plus",
        "libexec/gcc/*/*/collect2",
        "libexec/gcc/*/*/liblto_plugin.so",
        "libexec/gcc/*/*/lto-wrapper",
        "libexec/gcc/*/*/lto1",
    ]),
)

filegroup(
    name = "include",
    srcs = glob([
        "include/c++/**",
        "lib/gcc/*/*/include/**",
        "lib/gcc/*/*/include-fixed/**",
        "sysroot/usr/include/**",
    ]),
)

filegroup(
    name = "lib",
    srcs = glob([
        "lib/gcc/*/*/*.a",
        "lib/gcc/*/*/*.o",
        "lib64/libgcc_s.so",
        "lib64/libgcc_s.so.1",
        "sysroot/lib/*",
        "sysroot/usr/lib/*",
    ]),
)

filegroup(
    name = "static_runtime",
    srcs = ["lib64/libstdc++.a"],
)

filegroup(
    name = "dynamic_runtime",
    srcs = [
        "lib64/libgcc_s.so.1",
        "lib64/libstdc++.so.6",
    ],
)

filegroup(
    name = "as",
    srcs = ["x86_64-pc-linux-gnu/bin/as"],
)

filegroup(
    name = "ld",
    srcs = ["x86_64-pc-linux-gnu/bin/ld"],
)

filegroup(
    name = "ar",
    srcs = ["bin/ar"],
)

filegroup(
    name = "objcopy",
    srcs = ["bin/objcopy"],
)

filegroup(
    name = "strip",
    srcs = ["bin/strip"],
)

filegroup(
    name = "as_files",
    srcs = [
        ":as",
        ":gcc",
    ],
)

filegroup(
    name = "compiler_files",
    srcs = [
        ":as_files",
        ":include",
    ],
)

filegroup(
    name = "linker_files",
    srcs = [
        ":ar",
        ":gcc",
        ":ld",
        ":lib",
    ],
)

filegroup(
    name = "empty",
    srcs = [],
)

filegroup(
    name = "all_files",
    srcs = [
        ":compiler_files",
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
    as_files = ":as_files",
    compiler_files = ":compiler_files",
    dwp_files = ":empty",
    dynamic_runtime_lib = ":dynamic_runtime",
    linker_files = ":linker_files",
    objcopy_files = ":objcopy",
    static_runtime_lib = ":static_runtime",
    strip_files = ":strip",
    supports_param_files = 1,
    toolchain_config = ":config",
)
