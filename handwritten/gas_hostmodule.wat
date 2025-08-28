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
    ;; The maximum value for a u64.
    (global $U64_MAX i64 (i64.const 18_446_744_073_709_551_615))
    ;; The amount of stack remaining for use (represents a u64).
    (global $REMAINING_STACK (mut i64) (i64.const 10))

    ;; ==============================
    ;; ==== HOST-MANAGED Globals ====
    ;; ==============================

    ;; The amount of gas left for this execution (represents a u64).
    (global $GAS (mut i64) (i64.const 10))
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

    (func (export "finite_wasm_stack") (param $operand_size i64) (param $frame_size i64)
        ;; remaining_stack - operand_size.saturating_add(frame_size)
        global.get $REMAINING_STACK

        (call $saturating_add_u64 (local.get $operand_size) (local.get $frame_size))
        call $overflowing_sub_u64
        (if (param i64)
            (then
                ;; the subtraction overflowed!
                ;; the overflow amount is at TOS
                call $stack_exhausted
            )
            (else
                ;; The subtraction was successful!
                ;; the resulting amount is at TOS
                global.set $REMAINING_STACK
            )
        )

        ;; TODO: what do these constants actually mean?
        ;; used_gas = OP_COST * ((frame_size + 7) / 8)
        (i64.mul
            (i64.extend_i32_u (global.get $OP_COST))
            (i64.div_u
                (i64.add
                    (local.get $frame_size)
                    (i64.const 7))
                (i64.const 8)))
        call $consume_gas
    )

    (func (export "finite_wasm_unstack") (param $operand_size i64) (param $frame_size i64)
        ;; remaining_stack + operand_size.saturating_add(frame_size)
        global.get $REMAINING_STACK

        (call $saturating_add_u64 (local.get $operand_size) (local.get $frame_size))
        call $overflowing_add_u64
        (if (param i64)
            (then
                ;; the addition overflowed!
                ;; the overflow amount is at TOS
                call $unstack_overflowed
            )
            (else
                ;; The addition was successful!
                ;; the resulting amount is at TOS
                global.set $REMAINING_STACK
            )
        )
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
        (call $overflowing_sub_u64 (global.get $GAS) (local.get $gas_used))
        (if (param i64)
            (then
                ;; the subtraction overflowed!
                ;; the overflow amount is at TOS
                call $gas_exhausted
            )
            (else
                ;; The subtraction was successful!
                ;; the resulting amount is at TOS
                global.set $GAS
            )
        )
    )

    ;; Convert the parameters to a single constant representing the gas used.
    ;; The parameters encode gas used as a linear function:
    ;;     gas_used = constant + count * linear
    ;; If we overflow in this computation, we've maxed out the u64 space.
    ;; In response, we call `nearcore_params_overflowed` with the original parameters
    ;; for error handling.
    ;; We then continue on and deduct u64::MAX from the remaining gas.
    (func $linear_gas (param $count i32) (param $linear i64) (param $constant i64)
        (local $gas i64)
        ;; gas_used = constant + count * linear

        ;; count * linear
        (call $checked_mul_u64 (i64.extend_i32_u (local.get $count)) (local.get $linear))
        if (param i64) (result i64)
            drop
            ;; multiply wrapped! notify the host
            (call $params_overflowed (local.get $count) (local.get $linear) (local.get $constant))

            ;; result: u64::MAX
            global.get $U64_MAX
        end
        ;; leave 'count * linear' TOS

        ;; gas = constant + count * linear
        local.get $constant
        call $checked_add_u64
        if (param i64) (result i64)
            drop
            ;; multiply wrapped! notify the host
            (call $params_overflowed (local.get $count) (local.get $linear) (local.get $constant))

            ;; result: u64::MAX
            global.get $U64_MAX
        end

        ;; leave 'constant + count * linear' TOS
        call $consume_gas
    )

    ;; overflowing_sub: subtract two u64s, if it overflows return amount
    ;; Returns: (res: i64, overflowed: i32)
    ;;          res = b - a if b > a, else a - b
    (func $overflowing_sub_u64 (param $a i64) (param $b i64) (result i64 i32)
        (i64.gt_u (local.get $b) (local.get $a))
        (if (result i64 i32)
            (then
                ;; if b > a (unsigned), it will overflow!
                ;; return the amount it overflows by: b - a
                ;; AND that it overflowed (bool 1)
                local.get $b
                local.get $a
                i64.sub

                i32.const 1 ;; DID overflow
            )
            (else
                ;; will not overflow, just do a normal subtraction
                ;; return the subtraction result: a - b
                ;; AND that it didn't overflow (bool 0)
                local.get $a
                local.get $b
                i64.sub

                i32.const 0 ;; did NOT overflow
            )
        )
    )

    (func $overflowing_add_u64 (param $a i64) (param $b i64) (result i64 i32)
        (local $sum i64)

        ;; sum = a + b
        local.get $a
        local.get $b
        i64.add
        local.tee $sum
        local.get $sum

        ;; overflowed? = sum < a
        local.get $a
        i64.lt_u
        (if (param i64) (result i64 i32)
            ;; sum is TOS
            (then
                drop
                ;; (a + b) wrapped around; so amount = b - (MAX - a + 1)
                (i64.sub (local.get $b) (i64.sub (global.get $U64_MAX) (i64.add (local.get $a) (i64.const 1))))
                i32.const 1 ;; DID overflow
            )
            (else
                i32.const 0 ;; did NOT overflow
            )
        )
        ;; return (sum, overflow)
    )

    ;; checked_mul: multiply two u64s with overflow check
    ;; Returns: (product: i64, ok: i32)
    (func $checked_mul_u64 (param $a i64) (param $b i64) (result i64 i32)
        (local $res i64)
        (local $ok i32)

        ;; wrapped product
        local.get $a
        local.get $b
        i64.mul
        local.set $res

        ;; if b == 0, then ok = 1
        local.get $b
        i64.eqz
        (if (result i64 i32)
            (then
                local.get $res
                i32.const 1
                ;; return (res, ok)
            )
            (else
                local.get $res

                ;; check (res / b == a)
                local.get $res
                local.get $b
                i64.div_u
                local.get $a
                i64.eq
                ;; return (res, ok)
            )
        )
    )

    ;; checked_add: add two u64s with overflow check
    ;; Returns: (sum: i64, ok: i32)
    (func $checked_add_u64 (param $a i64) (param $b i64) (result i64 i32)
        (local $sum i64)
        ;; compute sum
        local.get $a
        local.get $b
        i64.add

        ;; keep a copy for return
        local.tee $sum

        ;; returns (sum,ok)
        local.get $sum
        ;; ok = (sum >= a)
        local.get $a
        i64.ge_u
    )

    ;; saturating_add: add two u64s, if overflow return max
    ;; Returns: (sum: i64)
    (func $saturating_add_u64 (param $a i64) (param $b i64) (result i64)
        (local $sum i64)
        ;; sum = a + b
        local.get $a
        local.get $b
        i64.add
        local.tee $sum      ;; save sum for select

        ;; if overflow, pick u64::MAX, else pick sum
        global.get $U64_MAX
        local.get $sum

        ;; check overflow: sum < a
        local.get $a
        i64.lt_u

        select
    )
)
