// This is an implementation of gas monitoring WITH
// optimizations through leveraging a guest analysis that
// aggregates the logic resulting in fewer instrumentation points.
// NO intrinsics from DSL
// Basically exactly what near does right now!

// Gas fees (make configurable):
// - end = 0
// - else = 0

use gas;
use analysis;

TINIT = 0;
TFILL = 0;
TCOPY = 0;

MINIT = 0;
MFILL = 0;
MCOPY = 0;

// Probes for GAS usage

wasm:opcode:*:before / @static analysis.should_inject(fid, pc) && @static analysis.linear_cost_at(fid, pc) == 0 / {
    var constant_cost: i32 = @static analysis.constant_cost_at(fid, pc);

    switch (@static analysis.instr_kind(fid, pc)) {
        case CONST => gas.decr_const(constant_cost);
        default => unreachable();
    }
}
wasm:opcode:*(arg0: i32):before / @static analysis.should_inject(fid, pc) && @static analysis.linear_cost_at(fid, pc) > 0  / {
    var linear_cost: i32 = @static analysis.linear_cost_at(fid, pc);
    var constant_cost: i32 = @static analysis.constant_cost_at(fid, pc);
    switch (@static analysis.instr_kind(fid, pc)) {
        case TINIT => gas.finite_wasm_table_init(arg0, linear_cost, constant_cost);
        case TFILL => gas.finite_wasm_table_fill(arg0, linear_cost, constant_cost);
        case TCOPY => gas.finite_wasm_table_copy(arg0, linear_cost, constant_cost);

        case MINIT => gas.finite_wasm_memory_init(arg0, linear_cost, constant_cost);
        case MFILL => gas.finite_wasm_memory_fill(arg0, linear_cost, constant_cost);
        case MCOPY => gas.finite_wasm_memory_copy(arg0, linear_cost, constant_cost);

        default => unreachable();
    }
}

// ================================
// ==== Probes for STACK usage ====
// ================================

// TODO