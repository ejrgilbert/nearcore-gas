(module
    ;; the amount the gas overflowed by
    (global $GAS_OVERFLOW (mut i64) (i64.const 0))
    (export "GAS_OVERFLOW" (global $GAS_OVERFLOW))

    ;; bool: whether the parameters overflowed
    (global $PARAM_OVERFLOWED (mut i32) (i32.const 0))
    (export "PARAM_OVERFLOWED" (global $PARAM_OVERFLOWED))

    ;; the amount the stack was overflowed by
    (global $STACK_OVERFLOW (mut i64) (i64.const 0))
    (export "STACK_OVERFLOW" (global $STACK_OVERFLOW))

    ;; the amount the stack was underflowed by
    (global $STACK_UNDERFLOW (mut i64) (i64.const 0))
    (export "STACK_UNDERFLOW" (global $STACK_UNDERFLOW))

    (func $nearcore_gas_exhausted (export "nearcore_gas_exhausted") (param $amt i64)
        (global.set $GAS_OVERFLOW (local.get $amt))
    )
    (func $nearcore_params_overflowed (export "nearcore_params_overflowed") (param i32 i64 i64)
        (global.set $PARAM_OVERFLOWED (i32.const 1))
    )
    (func $nearcore_stack_exhausted (export "nearcore_stack_exhausted") (param $amt i64)
        (global.set $STACK_OVERFLOW (local.get $amt))
    )
    (func $nearcore_unstack_overflowed (export "nearcore_unstack_overflowed") (param $amt i64)
        (global.set $STACK_UNDERFLOW (local.get $amt))
    )

    ;; Reset the state of this module
    (func $reset (export "reset")
        (global.set $GAS_OVERFLOW (i64.const 0))
        (global.set $PARAM_OVERFLOWED (i32.const 0))
        (global.set $STACK_OVERFLOW (i64.const 0))
        (global.set $STACK_UNDERFLOW (i64.const 0))
    )
)

(register "nearcore")

