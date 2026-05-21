# MICRO_UART_PROJECT
# 🔌 MICRO UART — Parameterized Serial Communication Core

> Parameterized UART (Universal Asynchronous Receiver-Transmitter) implemented in synthesizable Verilog RTL, with a directed testbench and functional coverage collection via QuestaSim.

**Author:** Lohith K S &nbsp;|&nbsp; **EMP ID.:** 6903 &nbsp;|&nbsp; **Tool:** QuestaSim 10.6c &nbsp;|&nbsp; **Language:** Verilog

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Module Hierarchy](#module-hierarchy)
- [Parameters](#parameters)
- [Port Description](#port-description)
- [Timing & Baud Rate](#timing--baud-rate)
- [FSM Description](#fsm-description)
- [File Structure](#file-structure)
- [Testbench Architecture](#testbench-architecture)
- [Test Plan & Results](#test-plan--results)
- [How to Run](#how-to-run)
- [Coverage Report](#coverage-report)
- [Known Bugs](#known-bugs)
- [Future Work](#future-work)

---

## Overview

This project implements a fully parameterized UART core in a loopback configuration (`UART_LOOPBACK`). The design supports configurable word length, system clock frequency, and baud rate. The transmitter (TX) and receiver (RX) are connected internally via a serial loopback line, enabling self-contained verification without an external serial link.

**Key features:**
- Parameterized word width (`WORD`), baud rate (`BAUD`), and clock frequency (`CLK_FREQ`)
- 4-state Moore TX FSM: `idle → start_bit → data_bit → stop_bit`
- 3-state RX FSM: `stop_bit → start_bit → data_bit`
- 3-FF input synchronizer for metastability protection
- Asynchronous active-low reset (`sys_rst_l`)
- 16× oversampled baud clock with center-bit sampling
- Directed testbench with 21 test cases, task-based driver/monitor/scoreboard

---

## Architecture

```
                         UART_LOOPBACK (top)
 ┌─────────────────────────────────────────────────────────┐
 │                                                         │
 │   sys_clk ──► ┌──────────┐                             │
 │               │   Baud   │── baud_clk ──┬──────────┐  │
 │   sys_rst_l ─►└──────────┘              │          │  │
 │                                         ▼          ▼  │
 │   xmitH ──────────────────────────► ┌──────┐   ┌──────┐
 │   xmit_dataH ─────────────────────► │  TX  │   │ sync │
 │                                     └──┬───┘   └──┬───┘
 │                uart_REC_dataH (serial) │           │   │
 │                ◄────────────────────── │           │   │
 │                loopback ───────────────────────────►   │
 │                                                    │   │
 │                                               ┌────▼──┐│
 │   rec_readyH ◄────────────────────────────── │  RX   ││
 │   rec_busy   ◄────────────────────────────── │       ││
 │   rec_dataH  ◄────────────────────────────── └───────┘│
 └─────────────────────────────────────────────────────────┘
```

---

## Module Hierarchy

| Module | File | Description |
|---|---|---|
| `UART_LOOPBACK` | `micro_UART.v` | Top-level wrapper; loopback interconnect |
| `Baud` | `Baud__1_.v` | Baud rate clock generator (`sys_clk` ÷ divider) |
| `TX` | `TX.v` | Serial transmitter — 4-state Moore FSM |
| `sync` | `Sync.v` | 3-FF synchronizer for async RX input |
| `RX` | `RX.v` | Serial receiver — 3-state FSM with center-bit sampling |

---

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `WORD` | `8` | Data word width in bits (supports 6, 7, 8) |
| `CLK_FREQ` | `50000000` | System clock frequency in Hz |
| `BAUD` | `9600` | Desired baud rate (e.g. 9600, 2400, 11600) |

---

## Port Description

### Inputs

| Port | Width | Description |
|---|---|---|
| `sys_clk` | 1 | System clock input |
| `sys_rst_l` | 1 | Active-low asynchronous reset |
| `xmitH` | 1 | Transmit enable — latches data and starts TX FSM |
| `xmit_dataH` | `WORD` | Parallel data to be transmitted serially |

### Outputs

| Port | Width | Description |
|---|---|---|
| `uart_REC_dataH` | 1 | Serial TX output (looped back to RX input) |
| `xmit_active` | 1 | HIGH during start, data, and stop bit transmission |
| `xmit_doneH` | 1 | Pulses HIGH for one baud cycle at end of frame |
| `rec_readyH` | 1 | HIGH when RX is idle and ready for a new packet |
| `rec_busy` | 1 | HIGH while RX is processing start or data bits |
| `rec_dataH` | `WORD` | Parallel received data; updated after each packet |

---

## Timing & Baud Rate

The `Baud` module generates a **16× oversampled** baud clock:

```
BAUD_FREQ = CLK_FREQ / (16 × BAUD)
baud_clk toggles every BAUD_FREQ/2 sys_clk cycles
```

**Default configuration (50 MHz, 9600 baud):**

| Parameter | Value |
|---|---|
| Divider (`BAUD_FREQ`) | 325 |
| `baud_clk` period | ~13 µs |
| 1 UART bit period | 16 × 13 µs = 208 µs |
| Full 8N1 frame | 10 bits × 208 µs = **2.08 ms** |

Each data bit is **center-sampled** at the **8th** baud clock cycle of its bit period to minimize noise sensitivity.

---

## FSM Description

### TX FSM (`TX.v`) — 4-state Moore machine

```
         xmitH=1
  idle ──────────► start_bit ──► data_bit ──► stop_bit
   ▲                                               │
   └───────────────────── (count==15) ─────────────┘
```

| State | uart_REC_dataH | xmit_active | xmit_doneH |
|---|---|---|---|
| `idle` | 1 | 0 | 0 |
| `start_bit` | 0 | 1 | 0 |
| `data_bit` | `data[i]` | 1 | 0 |
| `stop_bit` | 1 | 1 | 1 (last cycle) |

### RX FSM (`RX.v`) — 3-state FSM

```
  stop_bit ──► start_bit ──► data_bit
     ▲                           │
     └──────── (count==15, i==WORD, stop=1) ──┘
```

- Start bit validated over full 16 baud cycles (glitch rejection)
- Data bits sampled at `count == 7` (center of bit period)
- `rec_dataH` updated from `stored_out` on transition to `stop_bit`

---

## File Structure

```
micro-uart/
├── rtl/
│   ├── micro_UART.v        # Top-level loopback module
│   ├── TX.v                # Transmitter FSM
│   ├── RX.v                # Receiver FSM
│   ├── Baud__1_.v          # Baud rate generator
│   └── Sync.v              # 3-FF input synchronizer
├── tb/
│   └── tb.v                # Directed testbench (uart_test)
├── sim/
│   ├── log_file.log        # QuestaSim simulation log
│   └── coverage_file.ucdb  # Functional coverage database
├── docs/
│   └── Test_Coverage_MICRO_UART_LohithKS_6903.xlsx  # Test plan
└── README.md
```

---

## Testbench Architecture

```
  ┌─────────────────────────────────────────────────────────────┐
  │                    uart_test  (tb.v)                        │
  │                                                             │
  │  ┌─────────────┐  xmitH/xmit_data_h  ┌─────────────────┐  │
  │  │ xmitH_assert│ ──────────────────► │                 │  │
  │  │  tx_driver  │                     │   DUT           │  │
  │  └─────────────┘                     │  UART_LOOPBACK  │  │  ──► uart_xmit_data_h ──► tx_monitor ──► tx_scr
  │                                      │                 │  │
  │  ┌─────────────┐  uart_rec_data_h    │                 │  │  ──► rec_data_h / rec_ready ──► rx_monitor ──► rx_scr
  │  │  rx_driver  │ ──────────────────► │                 │  │
  │  └─────────────┘                     └─────────────────┘  │                                               │
  │                                                             │                                               ▼
  │  ┌──────────────┐  ┌────────────┐                          │                                    Simulation Report
  │  │  reset_dut   │  │ Clock gen  │                          │                                    (pass %, total)
  │  └──────────────┘  └────────────┘                          │
  └─────────────────────────────────────────────────────────────┘
```

### Testbench tasks

| Task | Role |
|---|---|
| `reset_dut` | Asserts `sys_rst` for 15 clock cycles, initializes all inputs |
| `xmitH_assert(N)` | Drives `xmitH` HIGH for N baud-clock ticks |
| `tx_driver(data, time)` | Loads `xmit_data_h` and holds for `time` bit periods |
| `rx_driver(data, start_ticks, stop_ticks)` | Drives start→data→stop bits on `uart_rec_data_h` |
| `tx_monitor` | Samples `uart_xmit_data_h` after 1.5× `BIT_PERIOD`, reconstructs byte |
| `rx_monitor` | Waits for `rec_ready`, captures `rec_data_h` |
| `tx_scr(ID)` | Compares TX monitored vs. expected; logs PASS/FAIL |
| `rx_scr(ID)` | Compares RX monitored vs. expected; logs PASS/FAIL |

---

## Test Plan & Results

### Simulation summary

| Metric | Value |
|---|---|
| Total test cases | 17 run (21 in plan) |
| Passed | **14** |
| Failed | **3** |
| Pass rate | **82%** |
| Simulation time | 19,036,642 ns |
| Tool | QuestaSim 10.6c |

### Test plan (priority-ordered)

| ID | Feature | Test Name | Priority | Status |
|---|---|---|---|---|
| 1 | `sys_clk` | CLK_toggling | P1 |  PASS |
| 2 | `sys_rst_l` | asyn_rst_assert_deassert | P1 |  PASS |
| 3 | `sys_rst_l` | rst_during_Tx_operation | P1 |  PASS |
| 4 | `sys_rst_l` | rst_during_Rx_operation | P1 |  PASS |
| 5 | `WORD` | parametrized_WORD (6,7,8) | P2 |  PASS |
| 6 | `BAUD` | parametrized_BAUD | P3  | PASS |
| 7 | `xmitH` | xmitH_assertion_for_data_TX | P3 |  PASS |
| 8 | `xmitH` | xmitH_assertion_between_TX_busy | P3 |  PASS |
| 9 | `xmit_dataH` | xmit_dataH_mid_transmission | P3 |  PASS |
| 10 | `xmitH` | No_assertion_xmitH | P3 |  PASS |
| 11 | `xmitH` | longer_assertion_xmitH_for_2Datas | P3 |  PASS |
| 12 | `uart_REC_dataH` | valid_start_bit_detection | P3 |  PASS |
| 13 | `uart_REC_dataH` | false_start_bit_detection | P3 |  PASS |
| 14 | `uart_REC_dataH` | valid_stop_bit_detection | P3 |  PASS |
| 15 | `rec_dataH` | all_zero_data_reception | P3 |  PASS |
| 16 | `rec_dataH` | all_one_data_reception | P3 |  PASS |
| 17 | `rec_busy` | rec_busy_assertion | P3 |  PASS |
| 18 | `rec_readyH` | rec_ready_assertion | P3 |  PASS |
| 19 | `rec_dataH` | noisy_input | P3 |  PASS |
| 20 | `uart_REC_dataH` | sending_two_pacs_continuously | P3 |  PASS |
| 21 | `uart_REC_dataH` | end_bit_not_received | P3 |  PASS |

---

## How to Run

### QuestaSim

```bash
# Compile all RTL and testbench
vlog rtl/micro_UART.v rtl/TX.v rtl/RX.v rtl/Baud__1_.v rtl/Sync.v tb/tb.v

# Simulate with coverage
vsim work.uart_test -l sim/log_file.log -coverage -c \
  -do "coverage save -onexit -codeAll sim/coverage_file.ucdb; run -all; exit"

# View coverage report
vcover report sim/coverage_file.ucdb -details
```

### Vivado (simulation only)

```tcl
# Add sources in Vivado → Simulation Sources
# Set tb.v as the top simulation module
# Run Behavioral Simulation
```

---

## Coverage Report

Coverage was collected using QuestaSim `-codeAll` and saved to `sim/coverage_file.ucdb`.

| Coverage Type | Observation | Status |
|---|---|---|
| Statement | Most RTL statements hit; reset-abort path uncovered | Partial |
| Branch | FSM transitions covered; WORD param variation missing | Partial |
| FSM – TX | All 4 states and transitions exercised |  Good |
| FSM – RX | All 3 states and transitions exercised |  Good |
| Toggle | Key control signals toggle correctly |  Good |
| Functional | 3 of 21 tests failing | 82% |

---

## Known Bugs

### Bug 1 — Reset during active TX (Test ID 3) `P1`
**Expected:** Asserting `sys_rst_l` mid-frame aborts TX and returns `uart_REC_dataH` to idle HIGH.  
**Observed:** TX monitor sampled `0xff` instead of `0x00` — FSM did not zero output on reset.  
**Root cause:** Reset abort path in TX FSM does not immediately drive the serial output to idle state.

### Bug 2 — Reset during active RX (Test ID 4) `P1`
**Expected:** `rec_dataH` clears to `0x00` on reset.  
**Observed:** Sampled `0xc1` — partial data was latched before reset propagated through the synchronizer.  
**Root cause:** The 3-FF synchronizer introduces latency; reset reaches RX FSM after data bits are already sampled.

### Bug 3 — Noisy input sampling (Test ID 19) `P3`
**Expected:** RX samples at the 8th baud cycle and captures `0x00` correctly even for unstable inputs.  
**Observed:** Sampled `0xff` — the input transition straddled the `count==7` sampling point.  
**Root cause:** Unstable input period overlaps the center-sampling moment; synchronizer output is HIGH at capture.

---

## Future Work

- [ ] Fix TX/RX reset abort RTL bugs (Tests 3 & 4)
- [ ] Fix noisy input sampling (Test 19) — consider majority voting (3-of-5)
- [ ] Add directed tests for `WORD = 6` and `WORD = 7` (Test 5)
- [ ] Add optional parity bit (even/odd/none) as a parameter
- [ ] Constrained-random testbench using SystemVerilog + UVM
- [ ] SVA assertions for reset, start-bit validation, and data sampling properties
- [ ] Achieve >95% code coverage
- [ ] FPGA synthesis targeting Xilinx / Intel with timing closure at 50 MHz

---

## License

This project is submitted as part of an academic verification exercise.  
© 2026 Lohith K S. All rights reserved.
