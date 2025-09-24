// This is an implementation of gas monitoring WITH
// optimizations through aggregating the logic resulting in
// fewer instrumentation points.

// Gas fees (make configurable):
// - end = 0
// - else = 0

use gas;

// Probes for GAS usage

// Default case
wasm:block:exit {
    // uses gas intrinsic that aggregates gas over the
    // basic block (does not aggregate linear gas opcodes)
    gas.finite_wasm_gas(gas_fee_constant as i32)
}

wasm:opcode:table.init(arg0: i32):before {
    gas.finite_wasm_table_init(arg0, gas_fee_linear as i32, gas_fee_constant as i32)
}

wasm:opcode:table.fill(arg0: i32):before {
    gas.finite_wasm_table_fill(arg0, gas_fee_linear as i32, gas_fee_constant as i32)
}

wasm:opcode:table.copy(arg0: i32):before {
    gas.finite_wasm_table_copy(arg0, gas_fee_linear as i32, gas_fee_constant as i32)
}

wasm:opcode:memory.init(arg0: i32):before {
    gas.finite_wasm_memory_init(arg0, gas_fee_linear as i32, gas_fee_constant as i32)
}

wasm:opcode:memory.fill(arg0: i32):before {
    gas.finite_wasm_memory_fill(arg0, gas_fee_linear as i32, gas_fee_constant as i32)
}

wasm:opcode:memory.copy(arg0: i32):before {
    gas.finite_wasm_memory_copy(arg0, gas_fee_linear as i32, gas_fee_constant as i32)
}

// ================================
// ==== Probes for STACK usage ====
// ================================

// TODO