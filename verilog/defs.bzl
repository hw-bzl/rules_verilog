"""verilog rules"""

load(
    ":verilog_info.bzl",
    _VerilogInfo = "VerilogInfo",
)
load(
    ":verilog_library.bzl",
    _verilog_library = "verilog_library",
)

VerilogInfo = _VerilogInfo
verilog_library = _verilog_library
