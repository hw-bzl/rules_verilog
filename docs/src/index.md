# rules_verilog

Bazel rules that provide the foundational Verilog/SystemVerilog
interfaces the wider HDL ecosystem builds on.

## Overview

`rules_verilog` deliberately ships a small surface area: a single
[`verilog_library`](./verilog_library.md) rule that collects sources,
headers, include paths, and dependencies, plus the
[`VerilogInfo`](./verilog_providers.md) provider it propagates. Downstream
rulesets — [`rules_verilator`](https://github.com/MrAMS/bazel_rules_verilator),
[`rules_vivado`](https://registry.bazel.build/modules/rules_vivado),
and other simulators, synthesis, and lint tools — consume that provider
to drive their own actions. Keeping the core minimal lets a single set
of `*_library` targets be reused across every downstream tool without
each ruleset re-inventing the source-collection layer.

Cross-language dependencies onto VHDL entities are declared via
`vhdl_deps` (from [`rules_vhdl`](https://registry.bazel.build/modules/rules_vhdl))
and surface on `VerilogInfo.vhdl_deps` for consumers walking mixed-language
designs.

## Quick start

### `MODULE.bazel`

```python
bazel_dep(name = "rules_verilog", version = "{version}")
```

### `hello/hello.sv`

```systemverilog
module hello (
    input  wire clk,
    input  wire rst,
    output reg  led
);
  always_ff @(posedge clk) begin
    if (rst) led <= 1'b0;
    else     led <= ~led;
  end
endmodule
```

### `hello/BUILD.bazel`

```python
load("@rules_verilog//verilog:defs.bzl", "verilog_library")

verilog_library(
    name = "hello",
    srcs = ["hello.sv"],
    top_module = "hello",
    standard = "2012",
)
```

The `:hello` target is now a `VerilogInfo` producer that any downstream
rule — a simulator, a synthesizer, a linter — can consume without
knowing anything else about how the sources are organized.

### Composing libraries

```python
load("@rules_verilog//verilog:defs.bzl", "verilog_library")

verilog_library(
    name = "bus_headers",
    hdrs = ["axi_params.svh"],
    includes = ["include/bus"],
)

verilog_library(
    name = "core",
    srcs = ["core.sv"],
    hdrs = ["core_defines.svh"],
    library = "my_core",
    standard = "2012",
)

verilog_library(
    name = "soc",
    srcs = ["soc_top.sv"],
    deps = [
        ":bus_headers",
        ":core",
    ],
    data = ["rom_init.hex"],
    top_module = "soc_top",
)
```

Each target contributes its own sources and inherits the transitive
dep graph — downstream rules see a single merged `VerilogInfo`.

## Going further

- [Rules](./rules.md) — the public rule set.
- [`VerilogInfo`](./verilog_providers.md) — the provider passed to
  downstream rules (simulators, synthesis, lint).
