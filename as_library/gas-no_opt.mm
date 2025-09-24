// This is an implementation of gas monitoring WITHOUT any
// optimizations through aggregating the logic resulting in
// fewer instrumentation points.
// SOME intrinsics (DSL has bound variables representing `gas`)

// Gas fees (make configurable):
// - end = 0
// - else = 0

use gas;

ID_UNR = 0;

ID_TINIT = 0;
ID_TFILL = 0;
ID_TCOPY = 0;

ID_MINIT = 0;
ID_MFILL = 0;
ID_MCOPY = 0;

// Probes for GAS usage

// Default case
wasm:opcode:*:before
/
    // linear gas should be zero!
    gas_fee_linear == 0 &&

    // do not instrument unreachable
    op_id != ID_UNR &&

    // linear gas opcodes
    op_id != ID_TINIT &&
    op_id != ID_TFILL &&
    op_id != ID_TCOPY &&

    op_id != ID_MINIT &&
    op_id != ID_MFILL &&
    op_id != ID_MCOPY

    // TODO: NE stack opcodes either
/ {
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