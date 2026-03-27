"""verilog_library"""

load(":verilog_info.bzl", "VerilogInfo")

def _find_top(ctx, srcs, top = None):
    """Determine the top module entry point from sources.

    Resolution order: explicit `top` label > single src > src whose
    basename (sans extension) matches `ctx.label.name` > None.

    Args:
        ctx: The rule's context object.
        srcs: A list of File objects from `ctx.files.srcs`.
        top: An explicit File contender for the top entry point, or None.

    Returns:
        File or None: The resolved top entry point, or None if one
        could not be determined (e.g. a multi-source utility library).
    """
    if top:
        if top not in srcs:
            fail("`top` was not found in `srcs`. Please add `{}` to `srcs` for {}".format(
                top.path,
                ctx.label,
            ))
        return top

    if len(srcs) == 1:
        return srcs[0]

    matched = None
    for src in srcs:
        basename = src.basename
        if basename.endswith(".sv"):
            basename = basename[:-3]
        elif basename.endswith(".v"):
            basename = basename[:-2]
        else:
            continue

        if basename == ctx.label.name:
            if matched:
                fail("Multiple files match candidates for `top`. Please explicitly specify which to use for {}".format(
                    ctx.label,
                ))
            matched = src

    return matched

def _verilog_library_impl(ctx):
    """Collects Verilog sources and transitive dependency info.

    Args:
      ctx: The context for this rule.

    Returns:
      A list of providers: VerilogInfo and DefaultInfo.
    """
    top = _find_top(ctx, ctx.files.srcs, ctx.file.top)

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
            top = top,
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
        "top": attr.label(
            doc = "The top module entry point. If unset, resolved from a single src or a src whose basename matches the target name.",
            allow_single_file = [".v", ".sv"],
        ),
    },
    provides = [VerilogInfo],
)
