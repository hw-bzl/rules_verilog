"""verilog_library"""

load("@rules_vhdl//vhdl:vhdl_info.bzl", "VhdlInfo")
load(":verilog_info.bzl", "VerilogInfo")

def _verilog_library_impl(ctx):
    """Collects Verilog sources and transitive dependency info.

    Cross-language VHDL deps declared via `vhdl_deps` are recorded on this
    target's `VerilogInfo.vhdl_deps` field, transitively walking both the
    direct entries' `VhdlInfo` and any VHDL deps inherited through the
    `deps` graph (i.e. a verilog_library dep that itself has `vhdl_deps`).

    Args:
      ctx: The context for this rule.

    Returns:
      A list of providers: VerilogInfo and DefaultInfo.
    """

    dep_infos = [dep[VerilogInfo] for dep in ctx.attr.deps]

    # Direct vhdl_deps + vhdl_deps inherited through the Verilog dep graph.
    # Storing the resolved depset on `VerilogInfo.vhdl_deps` means
    # consumers walk one merged transitive depset (no need to recurse
    # into `VerilogInfo.deps` and re-aggregate `vhdl_deps` themselves).
    direct_vhdl_dep_infos = [dep[VhdlInfo] for dep in ctx.attr.vhdl_deps]

    hdr_includes = [f.dirname for f in ctx.files.hdrs]
    if ctx.label.package:
        pkg_includes = [ctx.label.package + "/" + inc if inc else ctx.label.package for inc in ctx.attr.includes]
    else:
        pkg_includes = [inc for inc in ctx.attr.includes if inc]

    return [
        VerilogInfo(
            srcs = depset(ctx.files.srcs),
            hdrs = depset(ctx.files.hdrs),
            includes = depset(hdr_includes + pkg_includes),
            library = ctx.attr.library or ctx.label.name,
            data = depset(ctx.files.data),
            standard = ctx.attr.standard,
            top_module = ctx.attr.top_module,
            deps = depset(dep_infos, order = "postorder", transitive = [d.deps for d in dep_infos]),
            vhdl_deps = depset(
                direct_vhdl_dep_infos,
                order = "postorder",
                transitive = (
                    # Direct entries' own VHDL dep chains.
                    [d.deps for d in direct_vhdl_dep_infos] +
                    # VHDL deps inherited through the Verilog dep graph.
                    [d.vhdl_deps for d in dep_infos]
                ),
            ),
        ),
        DefaultInfo(
            files = depset(ctx.files.srcs + ctx.files.hdrs + ctx.files.data),
        ),
        coverage_common.instrumented_files_info(
            ctx,
            source_attributes = ["srcs", "hdrs"],
            dependency_attributes = ["deps", "vhdl_deps"],
            extensions = ["v", "sv", "vh", "svh"],
        ),
    ]

verilog_library = rule(
    doc = "Collect Verilog/SystemVerilog design units into a library target.",
    implementation = _verilog_library_impl,
    attrs = {
        "data": attr.label_list(
            doc = "Data files needed during compilation or simulation.",
            allow_files = True,
        ),
        "deps": attr.label_list(
            doc = "Other verilog_library targets this design depends on.",
            providers = [
                VerilogInfo,
            ],
        ),
        "hdrs": attr.label_list(
            doc = "Verilog or SystemVerilog headers.",
            allow_files = [".vh", ".svh"],
        ),
        "includes": attr.string_list(
            doc = "Additional include search paths, relative to this package.",
            default = [],
        ),
        "library": attr.string(
            doc = "Verilog/SystemVerilog library name this target compiles into. Defaults to the target's name.",
            default = "",
        ),
        "srcs": attr.label_list(
            doc = "Verilog or SystemVerilog sources.",
            allow_files = [".v", ".sv"],
        ),
        "standard": attr.string(
            doc = "Verilog/SystemVerilog standard version. Empty string means not specified; consumer rules apply their default.",
            default = "",
            values = ["", "1995", "2001", "2005", "2009", "2012", "2017", "2023"],
        ),
        "top_module": attr.string(
            doc = "The top module of this library. This is a local concept; the library's own entry-point module, not necessarily the global design top. Empty string means not specified.",
            default = "",
        ),
        "vhdl_deps": attr.label_list(
            doc = ("vhdl_library targets this Verilog/SV library instantiates " +
                   "(e.g. via component-bound VHDL entities). The rule walks " +
                   "each entry's `VhdlInfo` and stores the transitive VHDL " +
                   "dep chain on `VerilogInfo.vhdl_deps`, so consumers that " +
                   "already iterate `VerilogInfo` see cross-language sources " +
                   "by additionally walking that field. Empty by default — " +
                   "pure-Verilog targets get an empty `vhdl_deps` depset."),
            providers = [VhdlInfo],
        ),
    },
    provides = [VerilogInfo],
)
