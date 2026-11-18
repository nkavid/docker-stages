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
    version = "13.4.0"
    triple = "x86_64-pc-linux-gnu"

    tool_paths = [
        tool_path(name = "gcc", path = "bin/gcc"),
        tool_path(name = "ld", path = "bin/ld"),
        tool_path(name = "ar", path = "bin/ar"),
        tool_path(name = "cpp", path = "bin/cpp"),
        tool_path(name = "gcov", path = "bin/gcov"),
        tool_path(name = "nm", path = "bin/nm"),
        tool_path(name = "objcopy", path = "bin/objcopy"),
        tool_path(name = "objdump", path = "bin/objdump"),
        tool_path(name = "strip", path = "bin/strip"),
    ]

    cxx_include_directories = [
        "{}/include/c++/{}".format(root, version),
        "{}/include/c++/{}/{}".format(root, version, triple),
        "{}/include/c++/{}/backward".format(root, version),
    ]

    c_include_directories = [
        "{}/lib/gcc/{}/{}/include".format(root, triple, version),
        "{}/lib/gcc/{}/{}/include-fixed".format(root, triple, version),
        "{}/sysroot/usr/include".format(root),
    ]

    compile_flags = [
        "-U_FORTIFY_SOURCE",
        "-fstack-protector",
        "-fno-omit-frame-pointer",
        "-fdiagnostics-color=always",
        "-nostdinc",
    ]

    cxx_standards = ["c++17", "c++20", "c++23"]

    cxx_system_include_flags = ["-nostdinc++"] + [
        flag
        for directory in cxx_include_directories
        for flag in ["-isystem", directory]
    ]

    c_system_include_flags = [
        flag
        for directory in c_include_directories
        for flag in ["-isystem", directory]
    ]

    link_flags = [
        "-no-canonical-prefixes",
        "-Wl,--build-id=md5",
        "-Wl,--hash-style=gnu",
        "-Wl,-z,relro,-z,now",
    ]

    link_libs = ["-lm"]

    unfiltered_compile_flags = [
        "-no-canonical-prefixes",
        "-fno-canonical-system-headers",
        "-Wno-builtin-macro-redefined",
        "-D__DATE__=\"redacted\"",
        "-D__TIMESTAMP__=\"redacted\"",
        "-D__TIME__=\"redacted\"",
    ]

    features = [
        feature(name = "dbg"),
        feature(name = "opt"),
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
                _flags(all_compile_actions, ["-g"], ["dbg"]),
                _flags(all_compile_actions, [
                    "-g0",
                    "-O2",
                    "-D_FORTIFY_SOURCE=1",
                    "-DNDEBUG",
                    "-ffunction-sections",
                    "-fdata-sections",
                ], ["opt"]),
                _flags(all_cpp_compile_actions, cxx_system_include_flags),
                _flags(all_compile_actions, c_system_include_flags),
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
            flag_sets = [_flags(all_compile_actions, ["-Wall"])],
        ),
    ]

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = features,
        cxx_builtin_include_directories = cxx_include_directories + c_include_directories,
        builtin_sysroot = root + "/sysroot",
        toolchain_identifier = "gcc_" + version + "_linux_x86_64",
        host_system_name = "linux_x86_64",
        target_system_name = triple,
        target_cpu = "k8",
        target_libc = "glibc-2.35",
        compiler = "gcc",
        abi_version = "gcc",
        abi_libc_version = "glibc-2.35",
        tool_paths = tool_paths,
    )

cc_toolchain_config = rule(
    implementation = _impl,
    attrs = {},
    provides = [CcToolchainConfigInfo],
)
