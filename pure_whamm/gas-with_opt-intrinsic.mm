// This is an implementation of gas monitoring WITH
// optimizations through aggregating the logic resulting in
// fewer instrumentation points.

// Gas fees (make configurable):
// - end = 0
// - else = 0

use gas;

var GAS: u32 = gas.GAS;

// Probes for GAS usage
fn update_gas(fee: u32) {
    if (GAS - fee <= 0) {
        gas.exhausted();
    } else {
        GAS = GAS - fee;
    }
}

fn linear_gas(count: i32, linear: u32, constant: u32) {
    var fee = (count * linear) + constant;
    update_gas(fee);
}

// Default case
wasm:block:exit {
    update_gas(gas_fee_constant);
}

wasm:opcode:table.init(arg0: i32):before {
    linear_gas(arg0, gas_fee_linear as i32, gas_fee_constant as i32)
}

wasm:opcode:table.fill(arg0: i32):before {
    linear_gas(arg0, gas_fee_linear as i32, gas_fee_constant as i32)
}

wasm:opcode:table.copy(arg0: i32):before {
    linear_gas(arg0, gas_fee_linear as i32, gas_fee_constant as i32)
}

wasm:opcode:memory.init(arg0: i32):before {
    linear_gas(arg0, gas_fee_linear as i32, gas_fee_constant as i32)
}

wasm:opcode:memory.fill(arg0: i32):before {
    linear_gas(arg0, gas_fee_linear as i32, gas_fee_constant as i32)
}

wasm:opcode:memory.copy(arg0: i32):before {
    linear_gas(arg0, gas_fee_linear as i32, gas_fee_constant as i32)
}

// ================================
// ==== Probes for STACK usage ====
// ================================

// TODO