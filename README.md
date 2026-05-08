# PMOD-DA3-SPI-LIKE-INTERFACE-USING-VERILOG
Pmod DA3 SPI MODE 0 interface using Verilog
<!-- ============================= -->
<!-- PMOD DAC SPI INTERFACE README -->
<!-- ============================= -->

<h1 align="center">PMOD DAC SPI Interface</h1>

<p align="center">
  Fixed-Rate SPI DAC Driver in Verilog for FPGA-Based Signal Generation
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Language-Verilog-blue.svg">
  <img src="https://img.shields.io/badge/Interface-SPI-green.svg">
  <img src="https://img.shields.io/badge/Target-FPGA-orange.svg">
  <img src="https://img.shields.io/badge/DAC-AD5766%20%2F%20AD5767-red.svg">
</p>

---

## Overview

This repository contains a fixed-rate SPI driver module designed for interfacing 16-bit DACs such as the AD5766 and AD5767 using a PMOD-style interface.

The architecture is specifically designed for deterministic timing applications where DAC update timing must remain constant and independent of SPI transaction latency.

The design includes:

- Fixed-rate input sampling
- FSM-based SPI controller
- Configurable SPI clock generation
- Shift-register serializer
- Inter-frame timing control

The module continuously captures the latest valid input data and transmits it at a precisely controlled interval.

---

## Features

<table>
<tr>
<td width="50%">

### Core Features

- 16-bit SPI transmission
- Deterministic timing
- SPI Mode 0 compatible
- Configurable SCLK divider
- Gap-controlled frame spacing
- Latest-sample capture logic

</td>

<td width="50%">

### Target Applications

- DDS waveform generation
- FPGA DAC streaming
- Signal generation systems
- Embedded instrumentation
- Real-time control systems

</td>
</tr>
</table>

---

## Module Structure

```text
pmod.v
│
├── Fixed-Rate Input Sampler
├── FSM Controller
├── SPI Clock Generator
├── Shift Register Serializer
└── Gap Timing Logic
