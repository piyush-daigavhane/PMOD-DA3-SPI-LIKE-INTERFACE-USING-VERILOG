# PMOD DAC SPI Interface

<div align="center">

![Verilog](https://img.shields.io/badge/Language-Verilog-blue?style=for-the-badge&logo=v&logoColor=white)
![FPGA](https://img.shields.io/badge/Platform-FPGA-orange?style=for-the-badge)
![Clock](https://img.shields.io/badge/Clock-100%20MHz-green?style=for-the-badge)
![SPI](https://img.shields.io/badge/SPI-12.5%20MHz-purple?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-red?style=for-the-badge)

**A deterministic, fixed-rate SPI driver for 16-bit DACs on FPGA**  
Designed for PMOD DA3 (AD5541A) · 100 MHz system clock · 666.67 kSa/s update rate

</div>

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Timing & Calculations](#timing--calculations)
  - [SPI Clock Frequency](#spi-clock-frequency)
  - [Frame Timing & SAMPLE_CYCLES](#frame-timing--sample_cycles)
  - [DAC Update Rate](#dac-update-rate)
- [Configuration Guide](#configuration-guide)
  - [Setting SPI Clock Frequency](#1-setting-spi-clock-frequency)
  - [Recalculating SAMPLE_CYCLES](#2-recalculating-sample_cycles)
  - [Verifying Update Rate](#3-verifying-update-rate)
- [Port Reference](#port-reference)
- [FSM State Diagram](#fsm-state-diagram)
- [Default Configuration Summary](#default-configuration-summary)
- [Design Philosophy](#design-philosophy)
- [Applications](#applications)
- [Notes & Caveats](#notes--caveats)

---

## Overview

This repository provides a synthesizable, **fixed-rate SPI driver** for driving 16-bit DACs such as the **PMOD DA3** (AD5541A-based) from an FPGA.

Unlike conventional SPI controllers where throughput is demand-driven, this module operates at a **deterministic, fixed update interval** — the SPI engine acts purely as a transport layer while all timing is governed by a configurable sampling counter. This is essential for applications requiring stable waveform generation, predictable DAC behavior, and jitter-free output.

The module is architected around a **100 MHz system clock** and internally generates the SPI clock, handles framing, and manages the CS/LDAC signals autonomously.

---

## Features

- ✅ Fixed-rate input sampling independent of incoming data rate
- ✅ FSM-based SPI transmission (Moore machine, 6 states)
- ✅ Configurable SPI clock via `SCLK_DIV` localparam
- ✅ Deterministic DAC update timing via `SAMPLE_CYCLES`
- ✅ Inter-frame gap control for stable CS timing
- ✅ `LDAC_N` permanently asserted LOW for immediate DAC latch-through
- ✅ Active-low asynchronous reset
- ✅ SPI Mode 0 (CPOL=0, CPHA=0)

---

## Architecture

```
            ┌─────────────────────────────────────────────────────┐
            │                      pmod.v                         │
            │                                                     │
  clk ─────►│  ┌────────────────┐     ┌──────────────────────┐   │
  rst_n ───►│  │  Fixed-Rate    │     │   SPI FSM Engine     │   ├──► CS
            │  │  Sampler       ├────►│                      │   ├──► SCLK
  data ────►│  │                │     │  IDLE→LOAD→START     │   ├──► DIN
data_valid►│  │  sample_cnt    │     │  →SHIFT→DONE→GAP     │   ├──► LDAC_N
            │  └────────────────┘     └──────────────────────┘   │
            │                                 ▲                   │
            │                    ┌────────────┘                   │
            │                    │   SCLK Generator               │
            │                    │   (clk_div_cnt, sclk_int)      │
            └────────────────────┴───────────────────────────────┘
```

The design is divided into three independent always blocks:

| Block | Function |
|---|---|
| **Fixed-Rate Sampler** | Captures `data` at a fixed interval; discards stale samples |
| **SCLK Generator** | Divides system clock to produce SPI clock; edge-detects falling edge |
| **FSM + Output Logic** | Controls CS, DIN, SCLK enable; drives shift register |

---

## Timing & Calculations

### SPI Clock Frequency

The SPI clock is produced by dividing the system clock using the `SCLK_DIV` localparam:

```
SCLK = f_clk / (2 × SCLK_DIV)
```

With the defaults:

```
f_clk    = 100 MHz
SCLK_DIV = 4
```

```
SCLK = 100 MHz / (2 × 4)
     = 12.5 MHz
```

> **PMOD DA3 SPI limit:** The AD5541A supports up to **50 MHz** SCLK. With `SCLK_DIV = 4`, the maximum supported system clock before violating this limit is:
> ```
> f_clk_max = 50 MHz × 2 × 4 = 400 MHz
> ```

---

### Frame Timing & SAMPLE_CYCLES

`SAMPLE_CYCLES` defines the total number of system clock cycles per DAC update frame. It is calculated as:

```
SAMPLE_CYCLES = SHIFT_CYCLES + OVERHEAD + MARGIN
```

| Component | Formula | Default Value |
|---|---|---|
| `SHIFT_CYCLES` | `16 × 2 × SCLK_DIV` | `16 × 2 × 4 = 128` |
| `OVERHEAD` | `1 (LOAD) + 1 (START) + 1 (DONE) + GAP_CYCLES` | `1+1+1+4 = 7` |
| `MARGIN` | Fixed safety delay | `15` |
| **`SAMPLE_CYCLES`** | Sum of above | **`150`** |

Expanding `SHIFT_CYCLES`:

```
SHIFT_CYCLES = 16 bits × 2 clock edges per SPI bit × SCLK_DIV
             = 16 × 2 × 4
             = 128 system clock cycles
```

The full frame is therefore:

```
SAMPLE_CYCLES = 128 + 7 + 15 = 150 clock cycles
```

---

### DAC Update Rate

Once `SAMPLE_CYCLES` is known, the DAC update rate follows directly:

```
Update Rate = f_clk / SAMPLE_CYCLES
```

```
Update Rate = 100 MHz / 150
            ≈ 666.67 kSa/s
```

This is the effective throughput of the output DAC stream.

---

## Configuration Guide

### 1. Setting SPI Clock Frequency

To target a specific SPI clock frequency:

```
SCLK_DIV = f_clk / (2 × SCLK)
```

**Example — 25 MHz SPI clock:**

```
SCLK_DIV = 100 MHz / (2 × 25 MHz)
         = 2
```

```verilog
localparam SCLK_DIV = 2;
```

---

### 2. Recalculating SAMPLE_CYCLES

After changing `SCLK_DIV`, recalculate:

```
SHIFT_CYCLES  = 16 × 2 × SCLK_DIV
OVERHEAD      = 1 + 1 + 1 + GAP_CYCLES   // always 7 with GAP_CYCLES=4
SAMPLE_CYCLES = SHIFT_CYCLES + OVERHEAD + MARGIN
```

**Example with `SCLK_DIV = 2`:**

```
SHIFT_CYCLES  = 16 × 2 × 2 = 64
OVERHEAD      = 7
MARGIN        = 15
SAMPLE_CYCLES = 64 + 7 + 15 = 86
```

---

### 3. Verifying Update Rate

```
Update Rate = f_clk / SAMPLE_CYCLES
            = 100 MHz / 86
            ≈ 1.163 MSa/s
```

> **Important:** `SAMPLE_CYCLES` must always exceed `SHIFT_CYCLES + OVERHEAD` to guarantee complete SPI frame transmission. The `MARGIN` term exists to ensure this. Do not reduce `MARGIN` below 4–8 cycles.

---

## Port Reference

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | Input | 1 | System clock (100 MHz default) |
| `rst_n` | Input | 1 | Active-low asynchronous reset |
| `data` | Input | 16 | Input sample to DAC |
| `data_valid` | Input | 1 | Asserted high when `data` is valid |
| `CS` | Output | 1 | SPI chip select (active low) |
| `LDAC_N` | Output | 1 | DAC latch enable (held LOW permanently) |
| `SCLK` | Output | 1 | SPI clock output |
| `DIN` | Output | 1 | SPI data output (MSB first) |

---

## FSM State Diagram

```
            ┌─────────┐
     ┌─────►│  IDLE   │◄──────────────────────┐
     │      └────┬────┘                        │
     │           │ sampled_valid               │
     │           ▼                             │
     │      ┌─────────┐                        │
     │      │  LOAD   │  Load shift_reg, CS=0  │
     │      └────┬────┘                        │
     │           │                             │
     │           ▼                             │
     │      ┌─────────┐                        │
     │      │  START  │  Enable SCLK           │
     │      └────┬────┘                        │
     │           │                             │
     │           ▼                             │
     │      ┌─────────┐                        │
     │      │  SHIFT  │  Shift 16 bits on      │
     │      │         │  falling SCLK edge     │
     │      └────┬────┘                        │
     │           │ bit_cnt==15 & sclk_falling  │
     │           ▼                             │
     │      ┌─────────┐                        │
     │      │  DONE   │  Disable SCLK, CS=1   │
     │      └────┬────┘                        │
     │           │                             │
     │           ▼                             │
     │      ┌─────────┐                        │
     └──────┤   GAP   │  Inter-frame delay     │
            └─────────┘──────────────────────►─┘
                  gap_cnt == GAP_CYCLES
```

---

## Default Configuration Summary

| Parameter | Value |
|---|---|
| System Clock | 100 MHz |
| `SCLK_DIV` | 4 |
| SPI Clock (SCLK) | 12.5 MHz |
| `GAP_CYCLES` | 4 |
| `SHIFT_CYCLES` | 128 |
| `OVERHEAD` | 7 |
| `MARGIN` | 15 |
| `SAMPLE_CYCLES` | 150 |
| DAC Update Rate | ≈ 666.67 kSa/s |
| PMOD DA3 Max SCLK | 50 MHz |
| Max Supported `f_clk` | 400 MHz |
| SPI Mode | Mode 0 (CPOL=0, CPHA=0) |
| Bit Order | MSB first |

---

## Design Philosophy

This module is built around a core principle: **timing must be governed by the system, not the SPI engine.**

Most SPI controllers emit data as fast as possible and let the throughput float with load. This design inverts that model — the `SAMPLE_CYCLES` counter is the master clock of the entire pipeline. The SPI FSM simply services whatever the sampler has captured, at a rate that is fixed, predictable, and independent of upstream data arrival.

This makes the module appropriate wherever output jitter is unacceptable:

- The sampler always produces exactly one output per `SAMPLE_CYCLES` window.
- Samples arriving faster than the update rate are silently overwritten (latest-wins).
- Samples arriving slower result in no transmission (latest_valid stays low).

The gap state (`GAP`) provides a clean SPI idle period between frames, ensuring CS deasserts cleanly and the DAC has sufficient hold time before the next transaction.

---

## Applications

- **DDS / Direct Digital Synthesis** — fixed-rate waveform output
- **FPGA DAC streaming** — real-time audio or signal playback
- **Embedded instrumentation** — deterministic analog output
- **Signal generation** — sine, triangle, arbitrary waveform at precise sample rates

---

## Notes & Caveats

- `LDAC_N` is permanently held **LOW**. This means the DAC output updates immediately at the end of each SPI transaction (transparent latch mode). If synchronised multi-channel updates are required, this signal must be driven externally.
- If `data_valid` is never asserted, the sampler will never trigger a transmission. The FSM remains in `IDLE` indefinitely.
- Incoming data arriving faster than the update interval is **not buffered** — only the most recent sample is retained. If sample history is required, a FIFO should be inserted upstream.
- Timing constraints (e.g., `set_output_delay`) should be applied to `CS`, `SCLK`, and `DIN` relative to the PMOD DA3 setup/hold requirements when targeting higher clock frequencies.
- The `$clog2` function is used for counter sizing — ensure your synthesis tool supports this (Vivado, Quartus, and most modern tools do).
