(module
    ;; ===============================
    ;; ==== Import host functions ====
    ;; ===============================

    ;; Called when gas is exhausted (host handles behavior).
    (import "nearcore" "nearcore_gas_exhausted" (func $gas_exhausted (param i64)))
    ;; Called when linear gas params overflow themselves.
    (import "nearcore" "nearcore_params_overflowed" (func $params_overflowed (param i32 i64 i64)))
    ;; Called when the max stack height is reached.
    (import "nearcore" "nearcore_stack_exhausted" (func $stack_exhausted (param i64)))
    ;; Called when the `unstack` operation goes below zero (should never happen, points to BUGGY behavior).
    (import "nearcore" "nearcore_unstack_overflowed" (func $unstack_overflowed (param i64)))

    ;; ============================
    ;; ==== HARD-CODED Globals ====
    ;; ============================

    ;; The gas cost associated with a basic opcode (represents a u32).
    (global $OP_COST i32 (i32.const 1))
    ;; The amount of stack remaining for use (represents a u64).
    (global $REMAINING_STACK i64 (i64.const 0))

    ;; ==============================
    ;; ==== HOST-MANAGED Globals ====
    ;; ==============================

    ;; The amount of gas left for this execution (represents a u64).
    (global $GAS (mut i64) (i64.const 0))
    (export "nearcore_gas" (global $GAS))

    ;; ==================
    ;; ==== CORE API ====
    ;; ==================

    (func (export "finite_wasm_gas") (param $gas_used i64)
        (call $consume_gas (local.get $gas_used))
    )

    (func (export "finite_wasm_memory_copy") (param $count i32) (param $linear i64) (param $constant i64)
        (call $linear_gas (local.get $count) (local.get $linear) (local.get $constant))
    )

    (func (export "finite_wasm_memory_fill") (param $count i32) (param $linear i64) (param $constant i64)
        (call $linear_gas (local.get $count) (local.get $linear) (local.get $constant))
    )

    (func (export "finite_wasm_memory_init") (param $count i32) (param $linear i64) (param $constant i64)
        (call $linear_gas (local.get $count) (local.get $linear) (local.get $constant))
    )

    (func (export "finite_wasm_table_copy") (param $count i32) (param $linear i64) (param $constant i64)
        (call $linear_gas (local.get $count) (local.get $linear) (local.get $constant))
    )

    (func (export "finite_wasm_table_fill") (param $count i32) (param $linear i64) (param $constant i64)
        (call $linear_gas (local.get $count) (local.get $linear) (local.get $constant))
    )

    (func (export "finite_wasm_table_init") (param $count i32) (param $linear i64) (param $constant i64)
        (call $linear_gas (local.get $count) (local.get $linear) (local.get $constant))
    )

    (func (export "finite_wasm_stack") (param $count i32) (param $linear i64) (param $constant i64)
        ;; TODO
    )

    (func (export "finite_wasm_unstack") (param $count i32) (param $linear i64) (param $constant i64)
        ;; TODO
    )

    ;; ===========================
    ;; ==== Utility Functions ====
    ;; ===========================
    
    ;; Deduct the NEARCORE_GAS global by the passed amount.
    ;; Fast case: The operation does not overflow and the remaining gas
    ;;            (NEARCORE_GAS) is updated
    ;; Slow case: IF this operation overflows, the NEARCORE_GAS amount stays the
    ;;            same and the `nearcore_gas_exhausted` function is called with
    ;;            the overflow amount.
    ;;
    ;; Example:
    ;; 1. NEARCORE_GAS is equal to 0x0000000000000001
    ;; 2. consume_gas is called with 0x0000000000000005
    ;; 3. consume_gas invokes nearcore_gas_exhausted with 0x0000000000000004
    ;; 4. At this point the host will either cause a trap in the module or update the
    ;;    NEARCORE_GAS global value
    (func $consume_gas (param $gas_used i64)
        ;; TODO
    )
    
    ;; Convert the parameters to a single constant representing the gas used.
    ;; The parameters encode gas used as a linear function:
    ;;     gas_used = constant + count * linear
    ;; If we overflow in this computation, we've maxed out the u64 space.
    ;; In response, we call `nearcore_params_overflowed` with the original parameters
    ;; for error handling.
    ;; We then continue on and deduct u64::MAX from the remaining gas.
    (func $linear_gas (param $count i32) (param $linear i64) (param $constant i64)
        ;; TODO
    )
)