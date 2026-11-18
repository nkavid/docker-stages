load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "feature",
    "flag_group",
    "flag_set",
    "tool_path",
    "with_feature_set",
)

all_compile_actions = [
    ACTION_NAMES.assemble,
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
    ACTION_NAMES.cpp_module_codegen,
]

all_cpp_compile_actions = [
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
    ACTION_NAMES.cpp_module_codegen,
]

all_link_actions = [
    ACTION_NAMES.cpp_link_executable,
    ACTION_NAMES.cpp_link_dynamic_library,
    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
]

def _flags(actions, flags, features = None):
    return flag_set(
        actions = actions,
        flag_groups = [flag_group(flags = flags)],
        with_features = [with_feature_set(features = features)] if features else [],
    )

def _impl(ctx):
    root = ctx.label.workspace_root
    version = "22"
    triple = "x86_64-unknown-linux-gnu"
    resource_dir = "{}/lib/clang/{}".format(root, version)

    tool_paths = [
        tool_path(name = "ar", path = "bin/llvm-ar"),
        tool_path(name = "cpp", path = "bin/clang-cpp"),
        tool_path(name = "dwp", path = "bin/llvm-dwp"),
        tool_path(name = "gcc", path = "bin/clang"),
        tool_path(name = "gcov", path = "bin/llvm-profdata"),
        tool_path(name = "ld", path = "bin/ld.lld"),
        tool_path(name = "llvm-cov", path = "bin/llvm-cov"),
        tool_path(name = "llvm-profdata", path = "bin/llvm-profdata"),
        tool_path(name = "nm", path = "bin/llvm-nm"),
        tool_path(name = "objcopy", path = "bin/llvm-objcopy"),
        tool_path(name = "objdump", path = "bin/llvm-objdump"),
        tool_path(name = "strip", path = "bin/llvm-strip"),
    ]

    cxx_include_directories = [
        "{}/include/c++/v1".format(root),
        "{}/include/{}/c++/v1".format(root, triple),
    ]

    target_flags = ["--target=" + triple]

    compile_flags = target_flags + [
        "--no-default-config",
        "-U_FORTIFY_SOURCE",
        "-fstack-protector",
        "-fno-omit-frame-pointer",
        "-fcolor-diagnostics",
        "-B{}/bin/".format(root),
        "-resource-dir",
        resource_dir,
    ]

    cxx_standards = ["c++17", "c++20", "c++23"]

    cxx_system_include_flags = ["-nostdinc++"] + [
        flag
        for directory in cxx_include_directories
        for flag in ["-cxx-isystem", directory]
    ] + [
        "-idirafter",
        resource_dir + "/include",
        "-Xclang",
        "-fno-cxx-modules",
        "-Wno-module-import-in-extern-c",
    ]

    link_flags = target_flags + [
        "--no-default-config",
        "-no-canonical-prefixes",
        "-fuse-ld=lld",
        "-resource-dir",
        resource_dir,
        "-Wl,--build-id=md5",
        "-Wl,--hash-style=gnu",
        "-Wl,-z,relro,-z,now",
        "-rtlib=compiler-rt",
        "-L{}/lib".format(root),
        "-L{}/lib/{}".format(root, triple),
    ]

    link_libs = [
        "-lm",
        "-lpthread",
        "-ldl",
    ]

    unfiltered_compile_flags = [
        "-no-canonical-prefixes",
        "-Wno-builtin-macro-redefined",
        "-D__DATE__=\"redacted\"",
        "-D__TIMESTAMP__=\"redacted\"",
        "-D__TIME__=\"redacted\"",
    ]

    features = [
        feature(name = "dbg"),
        feature(name = "opt"),
        feature(name = "supports_start_end_lib", enabled = True),
        feature(name = "supports_dynamic_linker", enabled = True),
        feature(name = "supports_pic", enabled = True),
        feature(name = "static_link_cpp_runtimes", enabled = True),
        feature(name = "static_linking_mode"),
        feature(
            name = "static_libgcc",
            enabled = True,
            flag_sets = [
                _flags(all_link_actions, ["-static-libgcc"], ["static_link_cpp_runtimes", "static_linking_mode"]),
            ],
        ),
    ] + [
        feature(
            name = standard,
            provides = ["cxx_standard"],
            flag_sets = [_flags(all_cpp_compile_actions, ["-std=" + standard])],
        )
        for standard in cxx_standards
    ] + [
        feature(
            name = "default_compile_flags",
            enabled = True,
            flag_sets = [
                _flags(all_compile_actions, compile_flags),
                _flags(all_compile_actions, ["-g", "-fstandalone-debug"], ["dbg"]),
                _flags(all_compile_actions, [
                    "-g0",
                    "-O2",
                    "-D_FORTIFY_SOURCE=1",
                    "-DNDEBUG",
                    "-ffunction-sections",
                    "-fdata-sections",
                ], ["opt"]),
                _flags(all_cpp_compile_actions, cxx_system_include_flags),
            ],
        ),
        feature(
            name = "default_link_flags",
            enabled = True,
            flag_sets = [
                _flags(all_link_actions, link_flags),
                _flags(all_link_actions, ["-Wl,--gc-sections"], ["opt"]),
            ],
        ),
        feature(
            name = "default_link_libs",
            enabled = True,
            flag_sets = [_flags(all_link_actions, link_libs)],
        ),
        feature(
            name = "unfiltered_compile_flags",
            enabled = True,
            flag_sets = [_flags(all_compile_actions, unfiltered_compile_flags)],
        ),
        feature(
            name = "warnings",
            flag_sets = [_flags(all_compile_actions, ["-Wall", "-Wthread-safety", "-Wself-assign"])],
        ),
    ]

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = features,
        cxx_builtin_include_directories = cxx_include_directories + [
            resource_dir + "/include",
            "%sysroot%/usr/include",
        ],
        builtin_sysroot = root + "/sysroot",
        toolchain_identifier = "llvm_22.1.8_linux_x86_64",
        host_system_name = "linux_x86_64",
        target_system_name = triple,
        target_cpu = "k8",
        target_libc = "glibc-2.35",
        compiler = "clang",
        abi_version = "clang",
        abi_libc_version = "glibc-2.35",
        tool_paths = tool_paths,
    )

cc_toolchain_config = rule(
    implementation = _impl,
    attrs = {},
    provides = [CcToolchainConfigInfo],
)
