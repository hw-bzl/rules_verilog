"""Analysis tests for verilog_library."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_vhdl//vhdl:vhdl_info.bzl", "VhdlInfo")
load("//verilog:defs.bzl", "VerilogInfo")

def _file_basenames(files):
    return sorted([f.basename for f in files])

def _leaf_provider_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[VerilogInfo]

    asserts.equals(env, ["leaf.sv"], _file_basenames(info.srcs.to_list()))
    asserts.equals(env, ["leaf.svh"], _file_basenames(info.hdrs.to_list()))
    asserts.equals(env, ["leaf.dat"], _file_basenames(info.data.to_list()))
    asserts.equals(env, "leaf", info.library)
    asserts.equals(env, [], info.deps.to_list())
    asserts.equals(env, "", info.standard)
    asserts.equals(env, 1, len(info.includes.to_list()))
    asserts.equals(env, "", info.top_module)
    asserts.equals(
        env,
        [],
        info.vhdl_deps.to_list(),
        "pure-Verilog leaf target must have an empty cross-language depset",
    )

    return analysistest.end(env)

def _transitive_deps_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[VerilogInfo]

    asserts.equals(env, ["top.sv"], _file_basenames(info.srcs.to_list()))

    dep_providers = info.deps.to_list()
    asserts.equals(env, 2, len(dep_providers))

    # Postorder guarantees dependencies before dependents (dep_a before dep_b).
    dep_src_order = [f.basename for d in dep_providers for f in d.srcs.to_list()]
    asserts.equals(env, ["dep_a.sv", "dep_b.sv"], dep_src_order)

    return analysistest.end(env)

def _custom_library_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[VerilogInfo]

    asserts.equals(env, "my_custom_lib", info.library)
    asserts.equals(env, "", info.standard)
    asserts.equals(env, ["dep_a.sv"], _file_basenames(info.srcs.to_list()))

    return analysistest.end(env)

def _legacy_standard_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[VerilogInfo]

    asserts.equals(env, "2001", info.standard)
    asserts.equals(env, ["dep_a.sv"], _file_basenames(info.srcs.to_list()))

    return analysistest.end(env)

def _explicit_includes_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[VerilogInfo]

    includes = info.includes.to_list()
    has_extra = any(["extra_inc" in inc for inc in includes])
    asserts.true(env, has_extra, "Expected 'extra_inc' in includes, got: %s" % includes)

    return analysistest.end(env)

def _top_module_explicit_test_impl(ctx):
    """Test that an explicit top_module attribute is used."""
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[VerilogInfo]

    asserts.equals(env, "dep_a", info.top_module)

    return analysistest.end(env)

def _top_module_default_test_impl(ctx):
    """Test that top_module defaults to empty string when not specified."""
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[VerilogInfo]

    asserts.equals(env, "", info.top_module)

    return analysistest.end(env)

def _verilog_library_single_provider_test_impl(ctx):
    """verilog_library never directly emits VhdlInfo.

    Locks in the contract that `verilog_library` ALWAYS provides only
    `VerilogInfo` + `DefaultInfo`, regardless of whether `vhdl_deps` is
    set. Cross-language deps are carried inside `VerilogInfo.vhdl_deps`
    (a depset[VhdlInfo]) rather than via a separate provider — keeps
    the rule's provider set unconditional and avoids consumers having
    to branch on `VhdlInfo in target` for a verilog_library target.
    """
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, VerilogInfo in target, "verilog_library must always provide VerilogInfo")
    asserts.false(
        env,
        VhdlInfo in target,
        "verilog_library must never directly provide VhdlInfo — " +
        "cross-language deps live in VerilogInfo.vhdl_deps",
    )
    return analysistest.end(env)

def _vhdl_deps_on_verilog_info_test_impl(ctx):
    """vhdl_deps surface on VerilogInfo.vhdl_deps, postorder + transitive.

    A `vhdl_deps`-using target keeps its own Verilog srcs and exposes the
    VHDL dep chain via `VerilogInfo.vhdl_deps`.
    """
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[VerilogInfo]

    asserts.equals(env, ["mixed.sv"], _file_basenames(info.srcs.to_list()))
    asserts.equals(env, "mixed_lib", info.library)

    # Direct + transitive: `vhdl_dep` is the direct vhdl_deps entry, and
    # `vhdl_transitive` is reached through `vhdl_dep`'s own `deps`.
    vhdl_dep_srcs = [
        f.basename
        for d in info.vhdl_deps.to_list()
        for f in d.srcs.to_list()
    ]
    asserts.equals(
        env,
        ["vhdl_transitive.vhd", "vhdl_dep.vhd"],
        vhdl_dep_srcs,
        "postorder walk should yield transitive VHDL srcs before direct ones",
    )
    return analysistest.end(env)

def _empty_verilog_library_carries_library_for_vhdl_test_impl(ctx):
    """Empty-verilog_library wrap pattern propagates library + vhdl_deps.

    Zero Verilog srcs + `library = ...` + `vhdl_deps = [...]`. Symmetric
    to the vhdl_library wrap pattern documented in rules_vhdl; lets a
    pure-VHDL source land in a named Verilog library namespace for
    simulator-runner consumers that read library from
    `VerilogInfo.library` while collecting VHDL srcs from the
    `VerilogInfo.vhdl_deps` chain.
    """
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[VerilogInfo]

    asserts.equals(env, [], info.srcs.to_list(), "wrap target must have no Verilog srcs")
    asserts.equals(env, "vhdl_namespace", info.library)

    vhdl_dep_srcs = [
        f.basename
        for d in info.vhdl_deps.to_list()
        for f in d.srcs.to_list()
    ]
    asserts.equals(env, ["vhdl_transitive.vhd", "vhdl_dep.vhd"], vhdl_dep_srcs)
    return analysistest.end(env)

def _vhdl_deps_inherit_through_verilog_deps_test_impl(ctx):
    """vhdl_deps inherit through a verilog_library `deps` chain.

    A verilog_library whose `deps` include another verilog_library that
    has `vhdl_deps` must see those VHDL deps via its own
    `VerilogInfo.vhdl_deps`. Locks in the transitive walk through the
    Verilog graph, not just through direct `vhdl_deps` entries.
    """
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[VerilogInfo]

    vhdl_dep_srcs = [
        f.basename
        for d in info.vhdl_deps.to_list()
        for f in d.srcs.to_list()
    ]
    asserts.equals(
        env,
        ["vhdl_transitive.vhd", "vhdl_dep.vhd"],
        vhdl_dep_srcs,
        "vhdl_deps from a verilog_library dep must flow into this target's vhdl_deps",
    )
    return analysistest.end(env)

def _bad_src_extension_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "expected .v or .sv")
    return analysistest.end(env)

leaf_provider_test = analysistest.make(_leaf_provider_test_impl)
transitive_deps_test = analysistest.make(_transitive_deps_test_impl)
custom_library_test = analysistest.make(_custom_library_test_impl)
legacy_standard_test = analysistest.make(_legacy_standard_test_impl)
explicit_includes_test = analysistest.make(_explicit_includes_test_impl)
top_module_explicit_test = analysistest.make(_top_module_explicit_test_impl)
top_module_default_test = analysistest.make(_top_module_default_test_impl)
verilog_library_single_provider_test = analysistest.make(_verilog_library_single_provider_test_impl)
vhdl_deps_on_verilog_info_test = analysistest.make(_vhdl_deps_on_verilog_info_test_impl)
empty_verilog_library_carries_library_for_vhdl_test = analysistest.make(
    _empty_verilog_library_carries_library_for_vhdl_test_impl,
)
vhdl_deps_inherit_through_verilog_deps_test = analysistest.make(
    _vhdl_deps_inherit_through_verilog_deps_test_impl,
)
bad_src_extension_test = analysistest.make(
    _bad_src_extension_test_impl,
    expect_failure = True,
)

def verilog_library_test_suite(name):
    """A test suite for `verilog_library`.

    Args:
        name (str): The name of the test suite.
    """
    leaf_provider_test(
        name = name + "_leaf_provider",
        target_under_test = ":leaf",
    )

    transitive_deps_test(
        name = name + "_transitive_deps",
        target_under_test = ":top",
    )

    custom_library_test(
        name = name + "_custom_library",
        target_under_test = ":custom_lib_target",
    )

    legacy_standard_test(
        name = name + "_legacy_standard",
        target_under_test = ":legacy_target",
    )

    explicit_includes_test(
        name = name + "_explicit_includes",
        target_under_test = ":with_includes",
    )

    top_module_explicit_test(
        name = name + "_top_module_explicit",
        target_under_test = ":explicit_top_module",
    )

    top_module_default_test(
        name = name + "_top_module_default",
        target_under_test = ":utility_lib",
    )

    # Pure-Verilog target: never provides VhdlInfo directly.
    verilog_library_single_provider_test(
        name = name + "_pure_verilog_single_provider",
        target_under_test = ":leaf",
    )

    # Mixed-language target: also never provides VhdlInfo directly,
    # cross-language deps live in VerilogInfo.vhdl_deps.
    verilog_library_single_provider_test(
        name = name + "_mixed_lib_single_provider",
        target_under_test = ":mixed_lib_target",
    )

    vhdl_deps_on_verilog_info_test(
        name = name + "_vhdl_deps_on_verilog_info",
        target_under_test = ":mixed_lib_target",
    )

    empty_verilog_library_carries_library_for_vhdl_test(
        name = name + "_empty_verilog_library_carries_library_for_vhdl",
        target_under_test = ":vhdl_namespace_wrap",
    )

    vhdl_deps_inherit_through_verilog_deps_test(
        name = name + "_vhdl_deps_inherit_through_verilog_deps",
        target_under_test = ":verilog_consumer_of_mixed",
    )

    bad_src_extension_test(
        name = name + "_bad_src_extension",
        target_under_test = ":bad_src",
    )

    native.test_suite(
        name = name,
        tests = [
            name + "_leaf_provider",
            name + "_transitive_deps",
            name + "_custom_library",
            name + "_legacy_standard",
            name + "_explicit_includes",
            name + "_top_module_explicit",
            name + "_top_module_default",
            name + "_pure_verilog_single_provider",
            name + "_mixed_lib_single_provider",
            name + "_vhdl_deps_on_verilog_info",
            name + "_empty_verilog_library_carries_library_for_vhdl",
            name + "_vhdl_deps_inherit_through_verilog_deps",
            name + "_bad_src_extension",
        ],
    )
