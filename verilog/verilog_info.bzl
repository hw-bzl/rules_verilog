"""VerilogInfo"""

def _verilog_info_init(
        *,
        srcs = None,
        hdrs = None,
        data = None,
        includes = None,
        library = "",
        standard = "",
        top_module = "",
        deps = None,
        vhdl_deps = None):
    """`provider(init=...)` constructor for `VerilogInfo`.

    Runs on every `VerilogInfo(...)` call so callers get sensible defaults
    for optional fields — no need to know the full schema. New fields
    added to the provider grow a default value here, so external
    constructors (Vivado BD-wrapper extractors, code generators emitting
    SV, etc.) stay forward-compatible without every downstream repo
    needing to add the new kwarg to their construction calls.

    Fields not supplied by the caller default to empty depsets or empty
    strings, matching the "this target contributes nothing on that axis"
    interpretation used across the ecosystem.

    Args:
        srcs: depset[File] of Verilog/SV sources. Defaults to `depset()`.
        hdrs: depset[File] of `.vh` / `.svh` headers. Defaults to `depset()`.
        data: depset[File] of runtime data files. Defaults to `depset()`.
        includes: depset[str] of include search paths. Defaults to `depset()`.
        library: str Verilog/SV library name. Defaults to `""`.
        standard: str Verilog/SV standard version. Defaults to `""`.
        top_module: str top-module name. Defaults to `""`.
        deps: depset[VerilogInfo] transitive Verilog dep chain. Defaults
            to `depset()`.
        vhdl_deps: depset[VhdlInfo] transitive cross-language dep chain.
            Defaults to `depset()`.

    Returns:
        dict of field name -> value, consumed by the provider machinery.
    """
    return {
        "data": data if data != None else depset(),
        "deps": deps if deps != None else depset(),
        "hdrs": hdrs if hdrs != None else depset(),
        "includes": includes if includes != None else depset(),
        "library": library,
        "srcs": srcs if srcs != None else depset(),
        "standard": standard,
        "top_module": top_module,
        "vhdl_deps": vhdl_deps if vhdl_deps != None else depset(),
    }

VerilogInfo, _new_verilog_info = provider(
    doc = "Verilog/SystemVerilog compilation information.",
    fields = {
        "data": "depset[File]: Data files needed during compilation for this target.",
        "deps": "depset[VerilogInfo]: Transitive dependency providers.",
        "hdrs": "depset[File]: Verilog/SV header files for this target.",
        "includes": "depset[str]: Include search paths for this target.",
        "library": "str: Verilog/SV library name for this target.",
        "srcs": "depset[File]: Verilog/SV source files for this target.",
        "standard": "str: Verilog/SystemVerilog standard version for this target.",
        "top_module": "str: The top module of this library.",
        "vhdl_deps": ("depset[VhdlInfo]: Transitive VHDL dependencies a " +
                      "Verilog/SV design instantiates via component-bound " +
                      "entities. Consumers walking this depset pick up " +
                      "VHDL srcs for the cross-language part of the dep " +
                      "graph alongside the Verilog part walked via `deps`. " +
                      "Empty for pure-Verilog design units. Symmetric to " +
                      "`VhdlInfo.verilog_deps` in rules_vhdl."),
    },
    init = _verilog_info_init,
)
