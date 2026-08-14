# Rules

The public rule surface of `rules_verilog`. Every downstream ruleset
(simulators, synthesis, lint) consumes the
[`VerilogInfo`](./verilog_providers.md) these targets propagate.

## Library

- [`verilog_library`](./verilog_library.md) — collect Verilog /
  SystemVerilog sources, headers, include paths, and dependencies
  (including cross-language `vhdl_deps`) into a single reusable target.

## Providers

- [`VerilogInfo`](./verilog_providers.md) — the provider passed to
  downstream rules.
