# ROM Files Directory

This directory contains game ROM data converted to VHDL format for the FPGA implementation.

## ⚠️ Important Legal Notice

**This project does not include the original Space Invaders ROM data due to copyright restrictions.**

The original Space Invaders arcade game ROM is copyrighted by Taito Corporation. Users must obtain legal ROM files through legitimate means before using this FPGA implementation.

## Required Files

You need to provide the following ROM files:

- `invaders.e` (2048 bytes) - CPU ROM 0x0000-0x07FF
- `invaders.f` (2048 bytes) - CPU ROM 0x0800-0x0FFF
- `invaders.g` (2048 bytes) - CPU ROM 0x1000-0x17FF
- `invaders.h` (2048 bytes) - CPU ROM 0x1800-0x1FFF

## ROM Conversion Process

Once you have legal ROM files, convert them to VHDL format:

### Method 1: Automatic Conversion Tool

```bash
# Use the provided ROM converter (if available)
python tools/rom_converter.py invaders.e invaders.f invaders.g invaders.h
```

### Method 2: Manual Conversion

1. **Concatenate ROM files** in correct order:
   ```bash
   cat invaders.e invaders.f invaders.g invaders.h > invaders_combined.bin
   ```

2. **Convert to VHDL** using hex dump and text editor:
   ```bash
   hexdump -v -e '16/1 "%02x " "\n"' invaders_combined.bin > rom_data.txt
   ```

3. **Create VHDL file** using the template structure in `invaders_rom_template.vhd`

### Method 3: Online Tools

Various online ROM-to-VHDL conversion tools are available. Ensure the output format matches the expected VHDL structure used by this project.

## VHDL Format Requirements

The generated `invaders_rom.vhd` file must contain:

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity invaders_rom is
    Port (
        clk  : in  STD_LOGIC;
        addr : in  STD_LOGIC_VECTOR (12 downto 0);
        data : out STD_LOGIC_VECTOR (7 downto 0)
    );
end invaders_rom;

architecture Behavioral of invaders_rom is
    type rom_type is array (0 to 8191) of STD_LOGIC_VECTOR (7 downto 0);
    constant ROM_DATA : rom_type := (
        -- ROM data goes here as hex values
        0 => x"00", 1 => x"00", -- ... continue for all 8192 bytes
        others => x"00"
    );
begin
    process(clk)
    begin
        if rising_edge(clk) then
            data <= ROM_DATA(conv_integer(addr));
        end if;
    end process;
end Behavioral;
```

## Verification

After conversion, verify your ROM file:

1. **Check file size**: Should be exactly 8192 bytes (8KB) total
2. **Test build**: Ensure project builds without errors
3. **Hardware test**: Verify game starts and plays correctly

## Legal Sources for ROMs

Legal ways to obtain Space Invaders ROM files:

- **Purchase original arcade board** and dump ROMs yourself
- **Licensed ROM collections** from legitimate distributors
- **MAME ROM sets** obtained through legal channels
- **Homebrew alternatives** that recreate the game logic

## Troubleshooting

### Common Issues

**Build errors about missing ROM:**
- Ensure `invaders_rom.vhd` exists in this directory
- Check VHDL syntax and format

**Game doesn't start:**
- Verify ROM data integrity
- Check ROM file concatenation order
- Ensure all 8192 bytes are present

**Strange game behavior:**
- Verify ROM dump quality
- Check for bit errors in conversion
- Ensure correct memory mapping

### Support

For ROM conversion issues:
- Check project documentation in `Documents/` directory
- Open an issue on GitHub with details about your conversion process
- Review the MAME Space Invaders driver for reference

---

**Remember**: Respect copyright laws and only use legally obtained ROM files. This project is for educational and preservation purposes.