# Building and Flashing the Bitstream

This guide provides the steps to synthesize the VHDL code into a bitstream file and flash it to the Tang Nano 9K FPGA.

## Prerequisites

- **[Gowin EDA](http://www.gowinsemi.com/en/support/download_eda/)** (v1.9.10 or later)
- **Tang Nano 9K** with USB programming cable



## Command-Line Build and Flash (Verified Working Method)

### Prerequisites

- **Gowin EDA v1.9.12** or later installed
- **Tang Nano 9K** connected via USB
- **No PATH requirements** - using absolute paths for reliability

### Build (Verified Method)

#### Option 1: Using TCL Shell (Recommended)
1. Open terminal in project root directory
2. Use absolute path to gw_sh.exe:
   ```bash
   "C:\Gowin\Gowin_V1.9.12_x64\IDE\bin\gw_sh.exe" build.tcl
   ```

#### Build TCL Script (build.tcl)
The project includes a working TCL build script with corrected Gowin TCL commands:
```tcl
open_project TN9K-Invaders.gprj
run syn
run pnr
```

**Note**: Uses correct `run syn` and `run pnr` syntax (not `process run` which is incorrect).

## SystemVerilog 2017 Support and Troubleshooting

This project uses **mixed-language design** with both VHDL and SystemVerilog files. The HDMI subsystem is implemented in SystemVerilog 2017, which requires proper language support configuration.

### SystemVerilog Compilation Issues

#### Common Error Symptoms:
```
ERROR (EX3444) : 'logic' is an unknown type
ERROR (EX3444) : 'int' is an unknown type
ERROR (EX3444) : 'bit' is an unknown type
ERROR (EX3863) : Syntax error near '@'
WARN (EX2950) : Extra semicolon is not allowed here in this dialect, use SystemVerilog mode instead
```

#### Root Cause:
Gowin EDA defaults to **Verilog 2001** parsing for `.sv` files, not SystemVerilog 2017.

### Solution Methods

#### Method 1: Use CLI with Standard TCL Commands (Recommended)
```bash
# Use gw_sh.exe command line interface
"C:\Gowin\Gowin_V1.9.12_x64\IDE\bin\gw_sh.exe" build.tcl
```

**Note**: The `set_option -verilog_language` command may not be supported in all Gowin EDA versions. The project file configuration (Method 2) is the preferred approach for SystemVerilog language settings.

#### Method 2: Project File Configuration (Alternative)
The project file `TN9K-Invaders.gprj` already includes SystemVerilog language settings:
```xml
<File path="src/hdmi/hdmi.sv" type="file.verilog" enable="1" language_version="systemverilog_2005"/>
```

**Note**: Despite `systemverilog_2005` tag, the actual SystemVerilog 2017 features are used and require CLI method for reliable compilation.

#### Method 3: GUI Configuration (Alternative)
In Gowin EDA IDE:
1. Open the project in GUI mode
2. Go to **Project → Configuration → Synthesis → Verilog Language**
3. Change from **Verilog 2001** (default) to **SystemVerilog**
4. Apply settings and build normally

#### Method 4: Command Line Help
To see available gw_sh.exe options:
```bash
# Check available command line options
"C:\Gowin\Gowin_V1.9.12_x64\IDE\bin\gw_sh.exe" --help
# or
"C:\Gowin\Gowin_V1.9.12_x64\IDE\bin\gw_sh.exe" -help
```

**Documentation Reference**: For complete TCL command documentation, refer to **SUG1220** (Gowin Software Tcl Commands User Guide)

### SystemVerilog Files in Project
The following files require SystemVerilog 2017 support:
- `src/hdmi/audio_clock_regeneration_packet.sv`
- `src/hdmi/audio_info_frame.sv`
- `src/hdmi/audio_sample_packet.sv`
- `src/hdmi/auxiliary_video_information_info_frame.sv`
- `src/hdmi/hdmi.sv`
- `src/hdmi/hdmi_encoder.sv`
- `src/hdmi/packet_assembler.sv`
- `src/hdmi/packet_picker.sv`
- `src/hdmi/serializer.sv`
- `src/hdmi/source_product_description_info_frame.sv`
- `src/hdmi/tmds_channel.sv`

### SystemVerilog 2017 Features Used
- **`logic` data type**: Multi-value logic type
- **`int` data type**: 32-bit signed integer
- **`bit` data type**: 2-state logic type
- **Always blocks**: `always_ff`, `always_comb`
- **Packed arrays**: `logic [7:0][15:0] data`
- **Interfaces and modports**: For HDMI protocol implementation
- **Advanced procedural constructs**: Enhanced loop and conditional syntax

### Verification Commands
After successful compilation with SystemVerilog support, verify output:
```bash
# Check synthesis completed successfully
ls impl/gwsynthesis/TN9K-Invaders.vg

# Check place & route completed
ls impl/pnr/TN9K-Invaders.fs

# Expected final output file for programming
# Should be ~3.5MB bitstream file
```

### Alternative: Pure VHDL Version (Not Available)
**Note**: This project originally had a pure VHDL version, but the HDMI implementation has been migrated to SystemVerilog for better HDMI protocol support. The SystemVerilog HDMI modules provide:
- Better parameterization for HDMI timings
- Cleaner packet assembly logic
- Enhanced audio/video synchronization

### Flash (Verified Working Method)

#### Step 1: Verify FPGA Connection
1. Connect Tang Nano 9K via USB
2. Scan for device:
   ```bash
   "C:\Gowin\Gowin_V1.9.12_x64\Programmer\bin\programmer_cli.exe" --scan
   ```
   Expected output:
   ```
   Device Info:
     Family: GW1NR
     Name: GW1N-9C GW1NR-9C
     ID: 0x1100481B
   ```

#### Step 2: Program FPGA (SRAM - Volatile)
**Use absolute paths for both programmer and bitstream file:**
```bash
"C:\Gowin\Gowin_V1.9.12_x64\Programmer\bin\programmer_cli.exe" --device GW1NR-9C --operation_index 2 --fsFile "E:\OneDrive\Desktop\FPGA\YN9K_SI\impl\pnr\TN9K-Invaders.fs"
```

#### Step 3: Program to Flash (Permanent - Optional)
To make the configuration permanent:
```bash
"C:\Gowin\Gowin_V1.9.12_x64\Programmer\bin\programmer_cli.exe" --device GW1NR-9C --operation_index 5 --fsFile "E:\OneDrive\Desktop\FPGA\YN9K_SI\impl\pnr\TN9K-Invaders.fs"
```


#### Programming Operation Codes
- **operation_index 2**: SRAM Program (volatile, for testing)
- **operation_index 5**: embFlash Erase,Program (permanent)
- **operation_index 6**: embFlash Erase,Program,Verify (permanent with verification)

### Critical Notes
- **Always use absolute paths** for both programmer executable and bitstream file
- **SRAM programming** is volatile (lost on power cycle) but faster for development
- **Flash programming** is permanent but takes longer
- Successful programming shows progress bar and "Finished" message

## Troubleshooting Build Issues

### SystemVerilog Language Errors
**Symptoms**:
- `'logic' is an unknown type`
- `'int' is an unknown type`
- `Syntax error near '@'`

**Solution**: Use CLI method with SystemVerilog 2017 flag (see SystemVerilog section above)

### TCL Command Errors
**Symptoms**:
- `unknown option: -verilog_language`
- `invalid command name "current_design"`
- `set_option -verilog_language sysv-2017` not recognized

**Solutions**:
1. **Use basic TCL build script** without experimental language options
2. **Configure via GUI**: Project → Configuration → Synthesis → Verilog Language
3. **Rely on project file settings**: The `.gprj` file includes `language_version="systemverilog_2005"`
4. **Check documentation**: Refer to SUG1220 for supported TCL commands in your Gowin EDA version

### Missing Files Errors
**Symptoms**:
- `File not found: src/snes_controller.vhd`
- `Entity 'snes_controller' not found`

**Solution**: Ensure all SNES references have been updated to SFC:
- File should be `src/sfc_controller.vhd`
- Entity should be `sfc_controller`

### Programming Errors
**Symptoms**:
- `Not found any data File`
- `Device not found`

**Solutions**:
1. **Missing bitstream**: Ensure `.fs` file exists in `impl/pnr/`
2. **Device connection**: Check USB cable and run `--scan` first
3. **File path**: Use absolute paths for both programmer and bitstream

### Clock Timing Violations
**Symptoms**:
- `Can't calculate clocks' relationship`
- `Timing violation` warnings

**Normal**: These warnings are expected for cross-clock domain signals and don't affect functionality

### Expected Programming Output
```
Programming...: [#########################] 100%
User Code is: 0x0000E73C
Status Code is: 0x0003F020
Finished.
Cost 3.6 second(s)
```

## Hardware Setup and Game Controls

### Required Hardware
- **HDMI Display**: 640x480@60Hz output (most monitors support this)
- **SFC Controller**: For game controls (connected to pins 75/76/77)
- **USB Power**: Via USB-C cable to Tang Nano 9K
- **Audio** (Optional): External amplifier + speakers connected to pins 33/34

### SFC Controller Pinout
- **Pin 75**: SFC Latch (output)
- **Pin 76**: SFC Clock (output)
- **Pin 77**: SFC Data (input)
- **VCC**: 3.3V or 5V
- **GND**: Ground

### Game Controls
- **D-pad Left/Right**: Move left/right
- **B Button**: Fire missile
- **Start Button**: Start game / Insert coin
- **Select Button**: Insert coin (alternative)

### Starting the Game
1. Connect HDMI cable between Tang Nano 9K and display
2. Connect SFC controller to pins 75/76/77
3. Power on Tang Nano 9K via USB
4. Game should start automatically on HDMI display
5. Press Start to begin playing

### Troubleshooting Hardware
- **No HDMI signal**: Check HDMI cable and display compatibility
- **No controller response**: Verify SFC connections and controller compatibility
- **Game not starting**: Re-program FPGA or check power connections
- **Build errors**: Ensure all VHDL files are VHDL-93 compatible and SystemVerilog files use 2017 standard
