/// Represents the u64 gas value (note that gas value is unsigned).
/// This global will be set by the runtime.
#[unsafe(no_mangle)]
pub static mut NEARCORE_GAS: u64 = 0;

/// Gas cost of a regular operation.
#[unsafe(no_mangle)]
static REGULAR_OP_COST: u32 = 1;

/// Stores the amount of stack space remaining
#[unsafe(no_mangle)]
static mut REMAINING_STACK: u64 = 0;

// The host-provided implementation of `nearcore_gas_exhausted`
// Will be called if gas is exhausted.
#[link(wasm_import_module = "nearcore")]
unsafe extern "C" {
    #[link_name="nearcore_gas_exhausted"]
    fn nearcore_gas_exhausted(overflow: u64);
    #[link_name="nearcore_params_overflowed"]
    fn nearcore_params_overflowed(count: u32, linear: u64, constant: u64);
    #[link_name="nearcore_stack_exhausted"]
    fn nearcore_stack_exhausted(overflow: u64);
    #[link_name="nearcore_unstack_overflowed"]
    fn nearcore_unstack_overflowed(overflow: u64);
}

/// Deduct the NEARCORE_GAS global by the passed amount.
/// Fast case: The operation does not overflow and the remaining gas
///            (NEARCORE_GAS) is updated
/// Slow case: IF this operation overflows, the NEARCORE_GAS amount stays the
///            same and the `nearcore_gas_exhausted` function is called with
///            the overflow amount.
///
/// Example:
/// 1. NEARCORE_GAS is equal to 0x0000000000000001
/// 2. consume_gas is called with 0x0000000000000005
/// 3. consume_gas invokes nearcore_gas_exhausted with 0x0000000000000004
/// 4. At this point the host will either cause a trap in the module or update the
///    NEARCORE_GAS global value
fn consume_gas(gas: u64) {
    unsafe {
        let (res, overflowed) = NEARCORE_GAS.overflowing_sub(gas);
        if overflowed {
            nearcore_gas_exhausted(gas - NEARCORE_GAS);
        } else {
            NEARCORE_GAS = res;
        }
    }
}

#[unsafe(no_mangle)]
pub fn finite_wasm_gas(gas: u64) {
    consume_gas(gas)
}

/// Convert the parameters to a single constant representing the gas used.
/// The parameters encode gas used as a linear function:
///     gas_used = constant + count * linear
/// If we overflow in this computation, we've maxed out the u64 space.
/// In response, we call `nearcore_params_overflowed` with the original parameters
/// for error handling.
/// We then continue on and deduct u64::MAX from the remaining gas.
fn linear_gas(count: u32, linear: u64, constant: u64) {
    // gas_used = constant + count * linear
    let linear = u64::from(count).checked_mul(linear).unwrap_or_else(|| unsafe {
        nearcore_params_overflowed(count, linear, constant);
        // If it wraps, it's maxed out the u64 space
        u64::MAX
    });
    let gas = constant.checked_add(linear).unwrap_or_else(|| unsafe {
        nearcore_params_overflowed(count, linear, constant);
        // If it wraps, it's maxed out the u64 space
        u64::MAX
    });
    consume_gas(gas);
}

#[unsafe(no_mangle)]
pub fn finite_wasm_memory_copy(
    count: u32,
    linear: u64,
    constant: u64,
) {
    linear_gas(count, linear, constant)
}

#[unsafe(no_mangle)]
pub fn finite_wasm_memory_fill(
    count: u32,
    linear: u64,
    constant: u64,
) {
    linear_gas(count, linear, constant)
}

#[unsafe(no_mangle)]
pub fn finite_wasm_memory_init(
    count: u32,
    linear: u64,
    constant: u64,
) {
    linear_gas(count, linear, constant)
}

#[unsafe(no_mangle)]
pub fn finite_wasm_table_copy(
    count: u32,
    linear: u64,
    constant: u64,
) {
    linear_gas(count, linear, constant)
}

#[unsafe(no_mangle)]
pub fn finite_wasm_table_fill(
    count: u32,
    linear: u64,
    constant: u64,
) {
    linear_gas(count, linear, constant)
}

#[unsafe(no_mangle)]
pub fn finite_wasm_table_init(
    count: u32,
    linear: u64,
    constant: u64,
) {
    linear_gas(count, linear, constant)
}

#[unsafe(no_mangle)]
pub fn finite_wasm_stack(
    operand_size: u64,
    frame_size: u64,
) {
    unsafe {
        let total_used = operand_size.saturating_add(frame_size);
        let (res, overflowed) = REMAINING_STACK.overflowing_sub(total_used);
        if overflowed {
            nearcore_stack_exhausted(total_used - REMAINING_STACK);
        } else {
            REMAINING_STACK = res;
        }
    }

    let gas = ((frame_size + 7) / 8) * u64::from(REGULAR_OP_COST);
    consume_gas(gas);
}

#[unsafe(no_mangle)]
pub fn finite_wasm_unstack(
    operand_size: u64,
    frame_size: u64,
) {
    unsafe {
        let total_replaced = operand_size.saturating_add(frame_size);
        let (res, overflowed) = REMAINING_STACK.overflowing_add(total_replaced);
        if overflowed {
            // (a + b) wrapped around; so amount = b - (MAX - a + 1)
            let overflow = total_replaced - (u64::MAX - REMAINING_STACK + 1);
            nearcore_unstack_overflowed(overflow);
        } else {
            REMAINING_STACK = res;
        }
    }
}

#[cfg(test)]
mod tests {
    use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
    use crate::{consume_gas, linear_gas, NEARCORE_GAS};

    static GAS_OVERFLOW: AtomicU64 = AtomicU64::new(0);
    static PARAM_OVERFLOW: AtomicBool = AtomicBool::new(false);

    #[unsafe(no_mangle)]
    pub extern "C" fn nearcore_gas_exhausted(overflow: u64) {
        GAS_OVERFLOW.store(overflow, Ordering::Relaxed)
    }
    #[unsafe(no_mangle)]
    pub extern "C" fn nearcore_params_overflowed(_count: u32, _linear: u64, _constant: u64) {
        PARAM_OVERFLOW.store(true, Ordering::Relaxed)
    }

    fn test_setup(initial_gas: u64) {
        unsafe {
            NEARCORE_GAS = initial_gas;
        }
        GAS_OVERFLOW.store(0, Ordering::Relaxed);
        PARAM_OVERFLOW.store(false, Ordering::Relaxed)
    }

    #[allow(static_mut_refs)]
    fn asserts(gas: u64, overflow: u64, params_overflowed: bool) {
        unsafe {
            assert_eq!(NEARCORE_GAS, gas, "Wrong gas value");
        }
        assert_eq!(overflow, GAS_OVERFLOW.load(Ordering::Relaxed), "Wrong overflow value");
        assert_eq!(params_overflowed, PARAM_OVERFLOW.load(Ordering::Relaxed), "Wrong overflow value");
    }

    #[test]
    fn gas_all() {
        enum TestCase {
            Const {
                init: u64,
                used: u64,
                gas_left: u64,
                overflow: u64
            },
            Linear {
                init: u64,
                count: u32,
                linear: u64,
                constant: u64,
                gas_left: u64,
                overflow_amt: u64,
                params_overflowed: bool
            }
        }
        impl TestCase {
            fn new_const(init: u64, used: u64, gas_left: u64, overflow: u64) -> Self {
                Self::Const {
                    init, used, gas_left, overflow
                }
            }
            fn new_linear(init: u64, count: u32, linear: u64, constant: u64, gas_left: u64, overflow_amt: u64, params_overflowed: bool) -> Self {
                Self::Linear {
                    init, count, linear, constant, gas_left, overflow_amt, params_overflowed,
                }
            }
        }
        let tests = vec![
            // const: no overflow
            TestCase::new_const(0, 0, 0, 0),
            TestCase::new_const(1, 1, 0, 0),
            // const: with overflow
            TestCase::new_const(1, 2, 1, 1),
            TestCase::new_const(1, 20, 1, 19),

            // linear: no overflow
            TestCase::new_linear(0, 0, 0, 0, 0, 0, false),
            TestCase::new_linear(1, 0, 0, 1, 0, 0, false),
            TestCase::new_linear(2, 2, 1, 0, 0, 0, false),
            TestCase::new_linear(3, 2, 1, 1, 0, 0, false),
            TestCase::new_linear(10, 2, 1, 1, 7, 0, false),
            TestCase::new_linear(u64::MAX, 0, 0, u64::MAX, 0, 0, false),
            // linear: with overflow
            TestCase::new_linear(2, 2, 1, 1, 2, 1, false),
            TestCase::new_linear(1, 0, 0, u64::MAX, 1, u64::MAX - 1, false),
            // linear: with param overflow
            TestCase::new_linear(2, 1, 1, u64::MAX, 2, u64::MAX - 2, true),
        ];

        // Tests must be sequential since the NEARCORE_GAS global isn't protected
        for testcase in tests {
            match testcase {
                TestCase::Const { init, used, gas_left, overflow } => {
                    test_setup(init);
                    consume_gas(used);

                    println!("CONST (@{init}): gas = {used}");
                    asserts(gas_left, overflow, false);
                }
                TestCase::Linear { init, count, linear, constant, gas_left, overflow_amt, params_overflowed } => {
                    test_setup(init);
                    linear_gas(count, linear, constant);
                    println!("LINEAR ({init}): gas = {constant} + ( {count} * {linear} )");
                    asserts(gas_left, overflow_amt, params_overflowed);
                }
            }
        }
    }

    #[test]
    fn wasm_stack() {
        todo!()
    }
}