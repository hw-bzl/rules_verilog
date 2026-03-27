"""Analysis tests for verilog_library."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
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
    asserts.equals(env, [], info.deps.to_list())
    asserts.equals(env, "", info.standard)
    asserts.equals(env, 1, len(info.includes.to_list()))
    asserts.equals(env, "", info.module_name)

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

def _module_name_explicit_test_impl(ctx):
    """Test that an explicit module_name attribute is used."""
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[VerilogInfo]

    asserts.equals(env, "dep_a", info.module_name)

    return analysistest.end(env)

def _module_name_default_test_impl(ctx):
    """Test that module_name defaults to empty string when not specified."""
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[VerilogInfo]

    asserts.equals(env, "", info.module_name)

    return analysistest.end(env)

def _bad_src_extension_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "expected .v or .sv")
    return analysistest.end(env)

leaf_provider_test = analysistest.make(_leaf_provider_test_impl)
transitive_deps_test = analysistest.make(_transitive_deps_test_impl)
legacy_standard_test = analysistest.make(_legacy_standard_test_impl)
explicit_includes_test = analysistest.make(_explicit_includes_test_impl)
module_name_explicit_test = analysistest.make(_module_name_explicit_test_impl)
module_name_default_test = analysistest.make(_module_name_default_test_impl)
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

    legacy_standard_test(
        name = name + "_legacy_standard",
        target_under_test = ":legacy_target",
    )

    explicit_includes_test(
        name = name + "_explicit_includes",
        target_under_test = ":with_includes",
    )

    module_name_explicit_test(
        name = name + "_module_name_explicit",
        target_under_test = ":explicit_module_name",
    )

    module_name_default_test(
        name = name + "_module_name_default",
        target_under_test = ":utility_lib",
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
            name + "_legacy_standard",
            name + "_explicit_includes",
            name + "_module_name_explicit",
            name + "_module_name_default",
            name + "_bad_src_extension",
        ],
    )
