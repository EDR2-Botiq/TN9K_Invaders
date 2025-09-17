# TN9K Space Invaders - Development Guide

This file provides technical guidance for developers working with the TN9K Space Invaders project.

## Project Overview

**TN9K Space Invaders** is a complete Space Invaders arcade game recreation for the **Tang Nano 9K FPGA** (GW1NR-9C), based on the original work by [pinballwizz/TangNano9K-Invaders](https://github.com/pinballwizz/TangNano9K-Invaders) and adapted for HDMI output and SNES controller support. It implements a complete vintage arcade system including:
- Intel 8080 CPU core (T80/T8080se)
- Original Space Invaders game logic and memory mapping
- HDMI video output with scan doubler and color overlays ✅ **Tested**
- SNES controller input for authentic gaming experience ⚠️ **Not Hardware Tested**
- PWM audio output ⚠️ **Not Hardware Tested**
- Direct VRAM processing with authentic timing

## Testing Status

**Verified Components:**
- ✅ FPGA synthesis and place & route
- ✅ HDMI video output and display compatibility
- ✅ System clock generation and timing

**Pending Hardware Verification:**
- ⚠️ SNES controller interface and button mapping
- ⚠️ PWM audio output and sound effects
- ⚠️ Complete gameplay testing with controller input

## Development Environment

### Required Tools
- **Gowin EDA v1.9.12** or later (FPGA synthesis and place & route)
- **Tang Nano 9K** with USB programming cable
- **Target Device**: GW1NR-9C (GW1NR-LV9QN88PC6/I5)
- **SNES Controller**: Standard or compatible gamepad

### Build Commands

**Synthesis and Place & Route:**
```bash
# Windows (adjust path as needed)
"C:\Gowin\Gowin_V1.9.12_x64\IDE\bin\gw_sh.exe" build.tcl

# Linux/macOS
gw_sh build.tcl
```

**Programming to SRAM (volatile, for development):**
```bash
# Windows
"C:\Gowin\Gowin_V1.9.12_x64\Programmer\bin\programmer_cli.exe" --device GW1NR-9C --operation_index 2 --fsFile "impl\pnr\TN9K-Invaders.fs"

# Linux/macOS
programmer_cli --device GW1NR-9C --operation_index 2 --fsFile impl/pnr/TN9K-Invaders.fs
```

**Programming to Flash (permanent):**
```bash
# Windows
"C:\Gowin\Gowin_V1.9.12_x64\Programmer\bin\programmer_cli.exe" --device GW1NR-9C --operation_index 5 --fsFile "impl\pnr\TN9K-Invaders.fs"

# Linux/macOS
programmer_cli --device GW1NR-9C --operation_index 5 --fsFile impl/pnr/TN9K-Invaders.fs
```

**Check device connection:**
```bash
# Windows
"C:\Gowin\Gowin_V1.9.12_x64\Programmer\bin\programmer_cli.exe" --scan

# Linux/macOS
programmer_cli --scan
```

## Code Architecture

### Top-Level Hierarchy
- **`invaders_top.vhd`**: Top-level entity with clock generation, I/O interfaces, and system integration
- **`invaders.vhd`**: Main game logic, CPU interface, and system controller
- **`T8080se.vhd`**: Intel 8080-compatible CPU wrapper
- **`T80/`**: Complete T80 CPU core implementation (ALU, microcode, registers)

### Key Components

**CPU Subsystem:**
- `T80/T80.vhd`: Main CPU core
- `T80/T80_ALU.vhd`: Arithmetic Logic Unit
- `T80/T80_MCode.vhd`: Microcode engine
- `T80/T80_Pack.vhd`: Type definitions and constants
- `T80/T80_Reg.vhd`: Register file

**Memory Subsystem:**
- `proms/invaders_rom.vhd`: Game ROM (automatically generated)
- `gen_ram.vhd`: Generic RAM generator for system memory
- `dpram.vhd`: Dual-port RAM implementation

**Video Subsystem:**
- `dblscan.vhd`: Scan doubler for modern displays
- `si_vram_to_tmds_portrait480.vhd`: VRAM to HDMI conversion (2025 enhancement)
- Hardware color overlays for authentic arcade appearance

**Audio Subsystem:**
- `invaders_audio.vhd`: Sound effect generation
- `dac.vhd`: PWM audio output

**Input/Control:**
- `snes_controller.vhd`: SNES controller interface with 12-button support

**Clock Management:**
- `gowin_rpll/`: Gowin-specific PLL implementations
- `gowin_clkdiv/`: Clock dividers

### Gowin rPLL Clock Formula

**Critical Formulas for rPLL Configuration:**
```
PFD = FCLKIN ÷ (IDIV_SEL + 1)
CLKOUT = FCLKIN × (FBDIV_SEL + 1) ÷ (IDIV_SEL + 1)
VCO = (FCLKIN × (FBDIV_SEL + 1) × ODIV_SEL) ÷ (IDIV_SEL + 1)
CLKOUTD = CLKOUT ÷ DYN_SDIV_SEL
```

**Parameter Constraints:**
- IDIV_SEL: 0-63 (input divider)
- FBDIV_SEL: 0-63 (feedback divider)
- ODIV_SEL: 2, 4, 8, 16, 32, 48, 64, 80, 96, 112, 128 (output divider)
- DYN_SDIV_SEL: 2-128 (even numbers, secondary divider)
- VCO range: 600-1200 MHz (GW1NR-9C)

**Current Configuration (gowin_rpll.vhd):**
- FCLKIN = 27 MHz (Tang Nano 9K oscillator)
- IDIV_SEL = 3
- FBDIV_SEL = 2
- ODIV_SEL = 32
- DYN_SDIV_SEL = 2

**Correct Calculation:**
- PFD = 27 ÷ (3+1) = **6.75 MHz**
- CLKOUT = 27 × (2+1) ÷ (3+1) = 27 × 3 ÷ 4 = **20.25 MHz**
- VCO = (27 × 3 × 32) ÷ 4 = **648 MHz** (within 600-1200 MHz range)
- CLKOUTD = 20.25 ÷ 2 = **10.125 MHz**

**Result:** CLKOUT ≈ 20MHz, CLKOUTD ≈ 10MHz (matches system requirements)

### How to Calculate Clock Frequencies

**Step-by-Step Process:**

1. **Identify Requirements:**
   - Input clock: 27 MHz (Tang Nano 9K)
   - Desired CLKOUT: ~20 MHz
   - Desired CLKOUTD: ~10 MHz

2. **Apply the Formula:**
   ```
   CLKOUT = FCLKIN × (FBDIV_SEL + 1) ÷ (IDIV_SEL + 1)
   ```

3. **Choose Parameters:**
   - Start with IDIV_SEL = 3 (divides input by 4)
   - For 20MHz target: 20 = 27 × (FBDIV_SEL + 1) ÷ 4
   - Solve: FBDIV_SEL + 1 = 20 × 4 ÷ 27 = 2.96 ≈ 3
   - Therefore: FBDIV_SEL = 2

4. **Verify VCO Constraints:**
   ```
   VCO = (27 × 3 × 32) ÷ 4 = 648 MHz
   ```
   Must be 600-1200 MHz ✓

5. **Calculate Secondary Output:**
   ```
   CLKOUTD = CLKOUT ÷ DYN_SDIV_SEL = 20.25 ÷ 2 = 10.125 MHz
   ```

**Important Notes:**
- VCO frequency MUST be within 600-1200 MHz range
- ODIV_SEL is used for VCO calculation, not direct output division
- Use online calculator: https://juj.github.io/gowin_fpga_code_generators/pll_calculator.html

### Critical Design Aspects

**Timing Requirements:**
- 27MHz input clock (Tang Nano 9K oscillator)
- 20MHz system clock (PLL generated)
- 10MHz CPU clock (for authentic timing)
- Precise HDMI pixel clock generation

**Memory Organization:**
- Original Space Invaders memory mapping preserved
- 8KB system RAM shared between CPU and video
- Direct VRAM access for real-time processing
- 2-stage pipeline compensates for BRAM latency

**FPGA Resource Constraints:**
- GW1NR-9C has limited LUTs and BRAM
- T80 CPU core optimized for resource usage
- Efficient memory mapping to minimize BRAM usage

## File Structure

```
src/
├── T80/                    # T80 CPU core files
├── gowin_rpll/            # Clock generation (Gowin PLL)
├── gowin_clkdiv/          # Clock dividers
├── invaders_top.vhd       # Top-level system
├── invaders.vhd           # Game logic core
├── T8080se.vhd           # CPU wrapper
├── *_audio.vhd           # Audio subsystem
├── dblscan.vhd           # Video processing
├── snes_controller.vhd   # SNES controller interface
├── TN9K-Invaders.cst     # Pin constraints
└── TN9K-SI.sdc           # Timing constraints

proms/
└── invaders_rom.vhd      # Game ROM data

impl/
├── gwsynthesis/          # Synthesis outputs
├── pnr/                  # Place & route outputs
└── temp/                 # Temporary files

Documents/
├── BUILD.md              # Detailed build instructions
├── Tang_Nano_9K_Complete_Reference.md  # Hardware reference
└── HDMI_IMPLEMENTATION_GUIDE.md        # Video system details
```

## Hardware Setup

**Required Connections:**
- HDMI display (640x480@60Hz)
- SNES controller (pins 75/76/77)
- USB power via USB-C
- Optional: Audio amplifier (pins 33/34)

**SNES Controller Pinout:**
- Pin 75: SNES Latch (output)
- Pin 76: SNES Clock (output)
- Pin 77: SNES Data (input)
- Controller VCC: 3.3V or 5V
- Controller GND: Ground

**Game Controls:**
- D-Pad Left/Right: Move left/right
- A Button: Fire
- Start Button: Start 1-player game
- Select Button: Insert coin / Start 2-player game

## Development Notes

- Always use absolute paths for Gowin tools
- SRAM programming is faster for development (volatile)
- Flash programming for permanent deployment
- Check device connection before programming
- VHDL-93 compatibility required for all source files
- Resource optimization critical for GW1NR-9C constraints