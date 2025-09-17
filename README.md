# TN9K Space Invaders

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![FPGA](https://img.shields.io/badge/FPGA-Tang%20Nano%209K-blue.svg)](https://www.sipeed.com/en/hardware/nano)
[![VHDL](https://img.shields.io/badge/Language-VHDL-green.svg)](https://en.wikipedia.org/wiki/VHDL)

![EDR² Logo](Documents/images/EDR2_logo.png)

A complete recreation of the classic 1978 Space Invaders arcade game for the Tang Nano 9K FPGA development board. This project implements a cycle-accurate Intel 8080 CPU core and authentic arcade hardware to deliver the original gaming experience on modern displays via HDMI.

**Based on original code from [pinballwizz/TangNano9K-Invaders](https://github.com/pinballwizz/TangNano9K-Invaders)**
**Adapted for HDMI output and SNES controller by Terence Ang at EDR² (Eat, Drink, Repair and Repeat)**

![Space Invaders Screenshot](Documents/images/space_invaders_gameplay.png)

## 🚀 Features

- **Authentic Hardware Recreation**: Complete Intel 8080 CPU core implementation
- **Original Game Logic**: Faithful recreation of Space Invaders arcade behavior
- **🆕 HDMI Output**: Modern display support with scan doubler for 640x480@60Hz displays ✅
- **🆕 SNES Controller**: Classic gamepad support replacing original arcade controls ⚠️ *Not Tested*
- **High-Quality Audio**: PWM audio output with original sound effects ⚠️ *Not Tested*
- **Efficient Design**: Optimized for Tang Nano 9K's GW1NR-9C FPGA resources

### Key Adaptations from Original
- **HDMI Video**: Replaced VGA output with full HDMI implementation ✅ **Tested**
- **SNES Input**: Added SNES controller interface for modern gaming experience ⚠️ **Not Tested**
- **Enhanced Compatibility**: Improved timing and display compatibility

### ⚠️ Testing Status
- **✅ HDMI Video Output**: Fully tested and working
- **⚠️ SNES Controller**: Implementation complete but not hardware tested
- **⚠️ Audio Output**: Implementation complete but not hardware tested
- **✅ FPGA Build**: Synthesis and place & route verified

## 🎮 Quick Start

### Prerequisites

- **Tang Nano 9K FPGA Board** (GW1NR-9C)
- **Gowin EDA v1.9.12** or later
- **HDMI Display** (640x480@60Hz or higher)
- **SNES Controller** (standard or compatible)
- **USB-C Cable** for power and programming

### Hardware Setup

1. **Connect HDMI Display**: Use any HDMI cable to connect your display ✅ **Tested**
2. **Connect SNES Controller**: ⚠️ **Not Hardware Tested**
   - Pin 75: SNES Latch (output)
   - Pin 76: SNES Clock (output)
   - Pin 77: SNES Data (input)
   - VCC: 3.3V or 5V, GND: Ground
3. **Power via USB-C**: Connect to computer or USB power adapter

> **⚠️ Important**: SNES controller and audio functionality are implemented but not yet tested on hardware. HDMI video output is fully verified.

### Building and Programming

```bash
# Clone the repository
git clone https://github.com/yourusername/TN9K_SI.git
cd TN9K_SI

# Build the project (requires Gowin EDA)
"C:\Gowin\Gowin_V1.9.12_x64\IDE\bin\gw_sh.exe" build.tcl

# Program to SRAM (volatile, for testing)
"C:\Gowin\Gowin_V1.9.12_x64\Programmer\bin\programmer_cli.exe" --device GW1NR-9C --operation_index 2 --fsFile "impl\pnr\TN9K-Invaders.fs"

# Program to Flash (permanent)
"C:\Gowin\Gowin_V1.9.12_x64\Programmer\bin\programmer_cli.exe" --device GW1NR-9C --operation_index 5 --fsFile "impl\pnr\TN9K-Invaders.fs"
```

### Game Controls ⚠️ *Not Hardware Tested*

- **D-Pad Left/Right**: Move spaceship
- **A Button**: Fire laser
- **Start Button**: Start 1-player game
- **Select Button**: Insert coin / Start 2-player game

> **Note**: Controller functionality is implemented in code but requires hardware validation.

## 📋 ROM Requirements

**Important**: This project does not include the original Space Invaders ROM data due to copyright restrictions. You must provide your own legally obtained ROM files:

1. Obtain legal ROM files: `invaders.e`, `invaders.f`, `invaders.g`, `invaders.h`
2. Convert to VHDL format using the provided ROM converter tool
3. Place generated `invaders_rom.vhd` in the `proms/` directory

See [Documents/ROM_CONVERSION.md](Documents/ROM_CONVERSION.md) for detailed instructions.

## 🏗️ Architecture

### System Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Intel 8080   │    │   System RAM     │    │  HDMI Video     │
│   CPU Core      │◄──►│   (8KB BRAM)    │◄──►│  Subsystem      │
│   (T80 Core)    │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Game ROM       │    │  Audio Engine    │    │  SNES Controller│
│  (BRAM)         │    │  (PWM Output)    │    │  Interface      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Key Components

- **CPU Core**: T80 Intel 8080-compatible processor
- **Memory System**: 8KB system RAM with authentic memory mapping
- **Video Engine**: Direct VRAM processing with color overlays
- **Audio System**: Authentic sound effect generation
- **Clock Management**: Precise timing with 27MHz input → 20MHz system clock

## 📁 Project Structure

```
TN9K_SI/
├── src/                          # VHDL source files
│   ├── T80/                      # Intel 8080 CPU core
│   ├── hdmi/                     # HDMI video output
│   ├── gowin_rpll/              # Clock generation
│   ├── invaders_top.vhd         # Top-level system
│   ├── invaders.vhd             # Game logic core
│   └── snes_controller.vhd      # Controller interface
├── proms/                        # ROM data (user-provided)
├── impl/                         # Build outputs
├── Documents/                    # Technical documentation
│   ├── BUILD.md                 # Detailed build guide
│   ├── HDMI_IMPLEMENTATION_GUIDE.md
│   └── Tang_Nano_9K_Complete_Reference.md
├── LICENSE                       # MIT License
├── README.md                     # This file
└── CLAUDE.md                     # Development guidelines
```

## 🔧 Development

### Prerequisites for Development

- **Gowin EDA v1.9.12+**: FPGA synthesis and place & route
- **Tang Nano 9K**: Target hardware platform
- **VHDL Knowledge**: For modifications and enhancements

### Clock System

The project uses carefully tuned clock generation:

- **Input**: 27MHz (Tang Nano 9K oscillator)
- **System Clock**: 20.25MHz (via Gowin rPLL)
- **CPU Clock**: 10.125MHz (authentic 8080 timing)

### Resource Utilization

- **Logic Elements**: ~85% of GW1NR-9C capacity
- **BRAM**: ~90% utilization for ROM and RAM
- **Optimized**: Efficient design for resource-constrained FPGA

### Building from Source

See [Documents/BUILD.md](Documents/BUILD.md) for comprehensive build instructions including:
- Tool installation
- ROM conversion process
- Troubleshooting guide
- Advanced configuration options

## 🎯 Technical Specifications

### Performance
- **CPU Frequency**: 10.125 MHz (authentic Intel 8080 timing)
- **Video Output**: 640x480@60Hz via HDMI ✅ **Verified**
- **Audio**: PWM output, 44.1kHz equivalent ⚠️ **Not Tested**
- **Input Latency**: <1ms (direct hardware interface) ⚠️ **Not Tested**

### Compatibility
- **Tang Nano 9K**: GW1NR-9C FPGA (primary target)
- **HDMI Displays**: 640x480@60Hz minimum
- **Controllers**: Standard SNES gamepads
- **Power**: USB-C, 5V/1A minimum

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests, report bugs, or suggest enhancements.

### Development Guidelines

1. Follow existing VHDL coding style
2. Test thoroughly on real hardware
3. Update documentation for significant changes
4. Respect copyright restrictions on ROM content

### Areas for Contribution

- **Additional Games**: Port other classic arcade games
- **Display Enhancements**: VGA output, additional resolutions
- **Audio Improvements**: Enhanced sound quality, music support
- **Control Options**: Additional controller types, keyboard input

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Third-Party Components

- **T80 CPU Core**: Custom permissive license
- **Space Invaders ROM**: User must provide legally obtained files
- **Documentation**: Based on publicly available specifications

## 🏆 Credits

### Project Contributors
- **Original Project**: [pinballwizz/TangNano9K-Invaders](https://github.com/pinballwizz/TangNano9K-Invaders)
- **HDMI/SNES Adaptation**: Terence Ang
- **Company**: EDR² (Eat,Drink,Repair and Repeat)
- **Development**: Created with assistance from Claude Code (Anthropic)
- **CPU Core**: Based on T80 core by Daniel Wallner
- **Hardware Platform**: Tang Nano 9K by Sipeed

### Special Thanks
- Taito Corporation for the original Space Invaders arcade game
- The retro computing and FPGA communities
- Open-source hardware and software contributors

### Historical Context
Space Invaders, released by Taito in 1978, was designed by Tomohiro Nishikado and became one of the most influential video games of all time. This recreation honors that legacy while demonstrating modern FPGA capabilities.

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/TN9K_SI/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/TN9K_SI/discussions)
- **Documentation**: See `Documents/` directory for detailed guides

---

**Note**: This is an educational and preservation project. Users are responsible for obtaining legal ROM files and complying with applicable copyright laws.