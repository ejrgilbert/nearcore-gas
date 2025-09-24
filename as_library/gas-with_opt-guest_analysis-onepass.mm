// This is an implementation of gas monitoring WITH
// optimizations through leveraging a guest analysis that
// aggregates the logic resulting in fewer instrumentation points.
// NO intrinsics from DSL

// Gas fees (make configurable):
// - end = 0
// - else = 0

use gas;
use analysis;

ID_TINIT = 0;
ID_TFILL = 0;
ID_TCOPY = 0;

ID_MINIT = 0;
ID_MFILL = 0;
ID_MCOPY = 0;

// Probes for GAS usage

// Aggregate gas for a basic block IF this location is not linear
wasm:opcode:*:before / ! @static analysis.is_linear(op_id) / {
    @static analysis.agg(op_id);
    var curr_gas: i32 = @static analysis.curr_gas();
    if (@static analysis.should_inject() && curr_gas > 0) {
        gas.decr_const(curr_gas);
        @static analysis.reset();
    }
}

wasm:opcode:*(arg0: i32):before / @static analysis.is_linear(op_id) / {
    // Option1: switch on op_id in the library
    gas.decr_linear(arg0, op_id);

    // Option2: one decr function
    var linear_cost: i32 = @static analysis.linear_cost_of(op_id);
    var constant_cost: i32 = @static analysis.constant_cost_of(op_id);
    gas.decr_linear(arg0, linear_cost, constant_cost);

    // Option3: match specific opcode to function (might change per analysis)
    // can optimize by constant prop on switch
    var linear_cost: i32 = @static analysis.linear_cost_of(op_id);
    var constant_cost: i32 = @static analysis.constant_cost_of(op_id);
    switch(op_id) {
        case ID_TINIT => gas.finite_wasm_table_init(arg0, linear_cost, constant_cost);
        case ID_TFILL => gas.finite_wasm_table_fill(arg0, linear_cost, constant_cost);
        case ID_TCOPY => gas.finite_wasm_table_copy(arg0, linear_cost, constant_cost);

        case ID_MINIT => gas.finite_wasm_memory_init(arg0, linear_cost, constant_cost);
        case ID_MFILL => gas.finite_wasm_memory_fill(arg0, linear_cost, constant_cost);
        case ID_MCOPY => gas.finite_wasm_memory_copy(arg0, linear_cost, constant_cost);
    }
}

// ================================
// ==== Probes for STACK usage ====
// ================================

// TODO