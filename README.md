# HostModule for Gas Instrumentation #

## Handwritten Implementation ##

Located at `as_library/handwritten/gas_hostmodule.wat`.

Tests are written in WAST, located in `as_library/handwritten/tests/` and can be run via:
```bash
./as_library/handwritten/test.sh
```

## Rust Implementation ##

For the Rust implementation, to build:
```
# Compiles to: target/wasm32-unknown-unknown/debug/gas_hostmodule.wat
cargo build --target wasm32-unknown-unknown 
```
