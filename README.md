# Sequential Booth Multiplier in VHDL

> For the detailed design description, verification results, utilization and other details, see the report: [Booth_Multiplier_Report.pdf](Booth_Multiplier_Report.pdf).

A small, parameterized signed multiplier based on **Booth's algorithm**, written in VHDL and verified with an exhaustive, self-checking testbench. The project also contains a deliberately broken copy of the design to show that the testbench really catches bugs.

## Why Booth's algorithm?

Booth's algorithm multiplies two's complement numbers directly: for each multiplier bit it looks at the current bit and the previous one, then either shifts, adds the multiplicand, or subtracts it. Its main advantages:

- **Signed numbers work out of the box.** Positive and negative operands go through exactly the same steps, so no separate sign-correction logic is needed.
- **Fewer additions for runs of ones.** A run of ones in the multiplier costs one subtraction at its start and one addition after its end, instead of one addition per bit.
- **Very little hardware.** The sequential version needs only one adder/subtractor, a few shift registers and a small FSM.
- **Basis for faster multipliers.** Radix-4 (modified) Booth encoding, used in real hardware multipliers, halves the number of partial products.

This design is the simple sequential version: one add/subtract and shift per iteration, controlled by an FSM.

## Repository contents

| File | Purpose |
|---|---|
| `multiplier.vhd` | The correct design (entity `multiplier`, generic `N`). |
| `tb_multiplier.vhd` | Self-checking testbench: tries **every** operand pair and compares with VHDL's `*`. Ends with `SIM DONE`. |
| `multiplier_error.vhd` | Copy of the design with one injected bug: `q_l` is not cleared in the START state. |
| `tb_multiplier_error.vhd` | Same testbench connected to `multiplier_error`. It is expected to stop with `ERROR`. |

## Interface

| Port | Dir. | Description |
|---|---|---|
| `N` (generic) | | Operand width in bits (default 5) |
| `clk` | in | Clock, rising edge |
| `rst` | in | Synchronous reset, active high |
| `enable` | in | Start request (one clock cycle is enough) |
| `multiplicand_i`, `multiplier_i` | in | Signed operands, must fit in N bits |
| `ready_o` | out | `'1'` when `result_o` is valid; drops when a new multiplication starts |
| `result_o` | out | Signed product |

**Usage:** apply both operands, pulse `enable` for one clock cycle, then wait for a rising edge of `ready_o` and read `result_o`.

## How it works

An FSM runs N iterations. Each iteration checks the bit pair (Q0, Q-1), optionally adds or subtracts the multiplicand, and performs an arithmetic right shift.

Two details that mattered:

- **The accumulator is N+1 bits wide** and the multiplicand is sign-extended. With N bits, `-16 * 1` (N = 5) breaks, because `0 - (-16) = +16` does not fit in 5 signed bits.
- **`q_l` and `accumulator` are cleared in START.** Otherwise leftovers from the previous multiplication leak into the next one (see the faulty version).

## Running the simulation (Vivado)

1. Create a project and add `multiplier.vhd` as a design source and `tb_multiplier.vhd` as a simulation source (set it as the simulation top).
2. Run the behavioral simulation and type `run all` in the Tcl console (the default run time is only 1000 ns).
3. Success looks like this:

   ```
   Failure: SIM DONE
   ```

   `Failure` is just the severity used to stop the simulation. A mismatch would print `Failure: ERROR` instead.

To change the operand width, change the generic `N` in the testbench. The loops adapt automatically. The number of pairs grows by a factor of 4 for every extra bit: N = 10 means over a million pairs and takes much longer than N = 5.

To try the faulty design, use `multiplier_error.vhd` together with `tb_multiplier_error.vhd` instead.

## Results

| N | Operand range | Pairs tested | Result |
|---|---|---|---|
| 5 | -16 ... 15 | 1,024 | Passed |
| 6 | -32 ... 31 | 4,096 | Passed |
| 7 | -64 ... 63 | 16,384 | Passed |
| 8 | -128 ... 127 | 65,536 | Passed |
| 9 | -256 ... 255 | 262,144 | Passed |
| 10 | -512 ... 511 | 1,048,576 | Passed |

**Bug-injection check.** Besides the `q_l` bug, four other single faults were tried on copies of the design (zero-extension instead of sign-extension, counter `N-1`, wrong sign bit in the shift, ADD/SUBTRACT swapped). The testbench caught all of them.

The `q_l` bug is the subtle one: it only shows up after a specific multiplication follows another one. For N = 7 the sweep stops at the pair `-64 * -31` (result 1920 instead of 1984), which a single-pair test or a reset before every multiplication would never find. This is why the testbench runs back to back, without resetting between pairs.

## Synthesis

Synthesized in Vivado 2025.2 (N = 5): no errors, no inferred latches, no DSP blocks. The only warnings come from the unused upper bits of the 32-bit `integer` ports. No constraints were set, so implementation and timing were not run.

## Limitations

- Operands outside the N-bit range are silently truncated.
- `result_o` is an `integer`, so the product must fit in 32 bits (N <= 16).
- Verified by simulation only.
- Latency depends on the operands (about 3-4 clock cycles per iteration).

## Possible next steps

- Fewer clock cycles per iteration (merge the SHIFT and CHECK_2 states).
- Radix-4 modified Booth encoding.
- Testbench extras: timeout watchdog, more informative assertion messages, reset during a multiplication.
