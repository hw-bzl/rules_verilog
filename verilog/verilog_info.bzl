"""VerilogInfo"""

VerilogInfo = provider(
    doc = "Verilog/SystemVerilog compilation information.",
    fields = {
        "data": "depset[File]: Data files needed during compilation for this target.",
        "deps": "depset[VerilogInfo]: Transitive dependency providers.",
        "hdrs": "depset[File]: Verilog/SV header files for this target.",
        "includes": "depset[str]: Include search paths for this target.",
        "module_name": "str: The top-level module name.",
        "srcs": "depset[File]: Verilog/SV source files for this target.",
        "standard": "str: Verilog/SystemVerilog standard version for this target.",
    },
)
