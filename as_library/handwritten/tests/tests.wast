;; Some utility functions encapsulated in a module
(module
    (import "near_gas" "nearcore_gas" (global $GAS (mut i64)))
    (import "near_gas" "finite_wasm_gas" (func $finite_wasm_gas (param i64)))
    (import "near_gas" "finite_wasm_memory_copy" (func $linear_gas (param i32) (param i64) (param i64)))

    (import "nearcore" "GAS_OVERFLOW" (global $GAS_OVERFLOW (mut i64)))
    (import "nearcore" "PARAM_OVERFLOWED" (global $PARAM_OVERFLOW (mut i32)))
    (import "nearcore" "STACK_OVERFLOW" (global $STACK_OVERFLOW (mut i64)))
    (import "nearcore" "STACK_UNDERFLOW" (global $STACK_UNDERFLOW (mut i64)))
    (import "nearcore" "reset" (func $reset_host))

    (func (export "get_gas_over") (result i64)
        global.get $GAS_OVERFLOW
    )
    (func $get_gas (export "get_gas") (result i64)
        global.get $GAS
    )
    (func $set_gas (export "set_gas") (param $amt i64)
        (global.set $GAS (local.get $amt))
    )

    (func $setup (export "test_setup") (param $init_gas i64)
        (call $set_gas (local.get $init_gas))
        call $reset_host
    )

    (func $assert_gas (param $gas_left i64)
        ;; $GAS == $gas_left
        (i32.eqz (i64.eq (global.get $GAS) (local.get $gas_left)))
        if
            unreachable
        end
    )
    (func $assert_gas_over (param $overflow_amt i64)
        ;; $GAS_OVERFLOW == $overflow_amt
        (i32.eqz (i64.eq (global.get $GAS_OVERFLOW) (local.get $overflow_amt)))
        if
            unreachable
        end
    )
    (func $assert_param_over (param $params_overflowed i32)
        ;; $PARAM_OVERFLOW == $params_overflowed
        (i32.eqz (i32.eq (global.get $PARAM_OVERFLOW) (local.get $params_overflowed)))
        if
            unreachable
        end
    )
    (func $assert_stack_over (param $stack_over_amt i64)
        ;; $STACK_OVERFLOW == $stack_over_amt
        (i32.eqz (i64.eq (global.get $STACK_OVERFLOW) (local.get $stack_over_amt)))
        if
            unreachable
        end
    )
    (func $assert_stack_under (param $stack_under_amt i64)
        ;; $STACK_UNDERFLOW == $stack_under_amt
        (i32.eqz (i64.eq (global.get $STACK_UNDERFLOW) (local.get $stack_under_amt)))
        if
            unreachable
        end
    )

    (func $asserts (export "asserts") (param $gas_left i64) (param $overflow_amt i64) (param $params_overflowed i32) (param $stack_over_amt i64) (param $stack_under_amt i64)
        (call $assert_gas (local.get $gas_left))
        (call $assert_gas_over (local.get $overflow_amt))
        (call $assert_param_over (local.get $params_overflowed))
        (call $assert_stack_over (local.get $stack_over_amt))
        (call $assert_stack_under (local.get $stack_under_amt))
    )

    (func $const_test (export "const_test") (param $init_gas i64) (param $used_gas i64) (param $gas_left i64) (param $overflow_amt i64)
        (call $setup (local.get $init_gas))
        (call $finite_wasm_gas (local.get $used_gas))
        (call $asserts (local.get $gas_left) (local.get $overflow_amt) (i32.const 0) (i64.const 0) (i64.const 0))
    )

    (func $linear_test (export "linear_test") (param $init_gas i64) (param $count i32) (param $linear i64) (param $constant i64) (param $gas_left i64) (param $overflow_amt i64) (param $params_overflowed i32)
        (call $setup (local.get $init_gas))
        (call $linear_gas (local.get $count) (local.get $linear) (local.get $constant))
        (call $asserts (local.get $gas_left) (local.get $overflow_amt) (local.get $params_overflowed) (i64.const 0) (i64.const 0))
    )
)

;; =========================
;; TEST: 'nearcore_gas' should be managed by the host
(assert_return (invoke "get_gas") (i64.const 10))

(invoke "set_gas" (i64.const 30))
(assert_return (invoke "get_gas") (i64.const 30))

;; =========================
;; TESTS: const, no overflow

;; const_test(                      $init_gas,    $used_gas,    $gas_left,    $overflow)
(assert_return (invoke "const_test" (i64.const 0) (i64.const 0) (i64.const 0) (i64.const 0)))
(assert_return (invoke "const_test" (i64.const 1) (i64.const 1) (i64.const 0) (i64.const 0)))

;; =========================
;; TESTS: const, with overflow

;; const_test(                      $init_gas,    $used_gas,    $gas_left,    $overflow)
(assert_return (invoke "const_test" (i64.const 1) (i64.const 2) (i64.const 1) (i64.const 1)))
(assert_return (invoke "const_test" (i64.const 1) (i64.const 20) (i64.const 1) (i64.const 19)))

;; =========================
;; TESTS: linear, no overflow

;; linear_test(                      $init_gas,    $count,       $linear,      $constant,    $gas_left,    $overflow_amt, $params_overflowed)
(assert_return (invoke "linear_test" (i64.const 0) (i32.const 0) (i64.const 0) (i64.const 0) (i64.const 0) (i64.const 0)  (i32.const 0)))
(assert_return (invoke "linear_test" (i64.const 1) (i32.const 0) (i64.const 0) (i64.const 1) (i64.const 0) (i64.const 0)  (i32.const 0)))
(assert_return (invoke "linear_test" (i64.const 2) (i32.const 2) (i64.const 1) (i64.const 0) (i64.const 0) (i64.const 0)  (i32.const 0)))
(assert_return (invoke "linear_test" (i64.const 3) (i32.const 2) (i64.const 1) (i64.const 1) (i64.const 0) (i64.const 0)  (i32.const 0)))
(assert_return (invoke "linear_test" (i64.const 10) (i32.const 2) (i64.const 1) (i64.const 1) (i64.const 7) (i64.const 0)  (i32.const 0)))
(assert_return (invoke "linear_test" (i64.const 18_446_744_073_709_551_615) (i32.const 0) (i64.const 0) (i64.const 18_446_744_073_709_551_615) (i64.const 0) (i64.const 0)  (i32.const 0)))

;; =========================
;; TESTS: linear, with overflow

;; linear_test(                      $init_gas,    $count,       $linear,      $constant,    $gas_left,    $overflow_amt, $params_overflowed)
(assert_return (invoke "linear_test" (i64.const 2) (i32.const 2) (i64.const 1) (i64.const 1) (i64.const 2) (i64.const 1)  (i32.const 0)))
(assert_return (invoke "linear_test" (i64.const 18_446_744_073_709_551_615) (i32.const 0) (i64.const 0) (i64.const 18_446_744_073_709_551_615) (i64.const 0) (i64.const 0)  (i32.const 0)))

;; =========================
;; TESTS: linear, with param overflow

;; linear_test(                      $init_gas,    $count,       $linear,      $constant,    $gas_left,    $overflow_amt, $params_overflowed)
(assert_return (invoke "linear_test" (i64.const 2) (i32.const 1) (i64.const 1) (i64.const 18_446_744_073_709_551_615) (i64.const 2) (i64.const 18_446_744_073_709_551_613)  (i32.const 1)))
