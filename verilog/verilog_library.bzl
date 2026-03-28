"""verilog_library"""

load(":verilog_info.bzl", "VerilogInfo")

def _verilog_library_impl(ctx):
    """Collects Verilog sources and transitive dependency info.

    Args:
      ctx: The context for this rule.

    Returns:
      A list of providers: VerilogInfo and DefaultInfo.
    """

    dep_infos = [dep[VerilogInfo] for dep in ctx.attr.deps]

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
            data = depset(ctx.files.data),
            standard = ctx.attr.standard,
            top_module = ctx.attr.top_module,
            deps = depset(dep_infos, order = "postorder", transitive = [d.deps for d in dep_infos]),
        ),
        DefaultInfo(files = depset(ctx.files.srcs + ctx.files.hdrs + ctx.files.data)),
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
    },
    provides = [VerilogInfo],
)
