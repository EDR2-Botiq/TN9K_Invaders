-------------------------------------------------------------------------------
--                        Space Invaders - Tang Nano 9k
--                     For Original Code  (see notes below)
--
--               Based on pinballwizz/TangNano9K-Invaders
--           Adapted for HDMI output and SFC controller
--                        by Terence Ang - EDR²
--                    (Eat, Drink, Repair and Repeat)
--                               2025
-------------------------------------------------------------------------------
--
-- Space Invaders top level for
-- HDMI display with sound and scan doubler
--
-- Version : 0300
--
-- Copyright (c) 2002 Daniel Wallner (jesus@opencores.org)
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-- The latest version of this file can be found at:
--      http://www.fpgaarcade.com
--
-- Limitations :
--
-- File history :
--
--      0241 : First release
--
--      0242 : added the ROM from mw8080.vhd
--
--      0300 : MikeJ tidy up for audio release
--------------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;
---------------------------------------------------------------------------------------
entity invaders_top is
	port(
		Clock_27          : in    std_logic;
		I_RESET           : in    std_logic;
		S2_BUTTON         : in    std_logic;  -- User button S2 (coin insert)

		-- SFC Controller interface
		SFC_LATCH         : out   std_logic;  -- Latch signal to controller
		SFC_CLK           : out   std_logic;  -- Clock signal to controller
		SFC_DATA          : in    std_logic;  -- Data from controller

		-- HDMI differential outputs
		hdmi_tx_clk_p     : out   std_logic;
		hdmi_tx_clk_n     : out   std_logic;
		hdmi_tx_p         : out   std_logic_vector(2 downto 0);
		hdmi_tx_n         : out   std_logic_vector(2 downto 0);
		O_AUDIO           : out   std_logic;  -- Mono audio output
        led               : out    std_logic_vector(5 downto 0)
		);
end invaders_top;
---------------------------------------------------------------------------------------
architecture rtl of invaders_top is

	signal reset           : std_logic;
	signal Rst_n_s         : std_logic;
	signal clock_20        : std_logic;
	signal clock_10        : std_logic;
	signal clock_tmds      : std_logic;  -- 126 MHz TMDS clock
	signal clock_pixel     : std_logic;  -- 25.2 MHz pixel clock
	signal DIP             : std_logic_vector(8 downto 1);
	signal RWE_n           : std_logic;
	signal Video           : std_logic;
	-- VideoRGB signals removed - color processing now handled in si_vram_to_tmds_portrait480
	signal HSync           : std_logic;
	signal VSync           : std_logic;
	signal HSync_X2        : std_logic;
	signal VSync_X2        : std_logic;
	-- scanlines signal removed - not used with direct VRAM processing
    --
	signal AD              : std_logic_vector(15 downto 0);
	signal RAB             : std_logic_vector(12 downto 0);
	signal RDB             : std_logic_vector(7 downto 0);
	signal RWD             : std_logic_vector(7 downto 0);
	signal IB              : std_logic_vector(7 downto 0);
	signal SoundCtrl3      : std_logic_vector(5 downto 0);
	signal SoundCtrl5      : std_logic_vector(5 downto 0);
    --
	signal Tick1us         : std_logic;
    --
	signal rom_data_0      : std_logic_vector(7 downto 0);
	signal ram_we          : std_logic;
	--
	-- Overlay signals removed - color processing now handled in si_vram_to_tmds_portrait480
    --
	signal Audio           : std_logic_vector(7 downto 0);
	-- HDMI signals
	signal hdmi_rgb        : std_logic_vector(23 downto 0);
	-- HDMI mono audio sample rate generation (48 kHz from 25.2 MHz)
	signal audio_sample_tick : std_logic;
	signal audio_sample_counter : unsigned(9 downto 0) := (others => '0');
	signal audio_mono_reg : std_logic_vector(15 downto 0);  -- Mono audio sampled at 48 kHz
	constant AUDIO_SAMPLE_DIV : natural := 525; -- 25,200,000 / 48,000 = 525
	-- Removed test pattern signals

	-- VRAM-to-TMDS signals
	signal vram_video_addr  : std_logic_vector(15 downto 0);
	signal vram_video_data  : std_logic_vector(7 downto 0);
	signal vram_tmds_r      : std_logic_vector(7 downto 0);
	signal vram_tmds_g      : std_logic_vector(7 downto 0);
	signal vram_tmds_b      : std_logic_vector(7 downto 0);
	signal vram_tmds_hsync  : std_logic;
	signal vram_tmds_vsync  : std_logic;
	signal vram_tmds_de     : std_logic;
	-- Removed test mode signal

	-- Dual-port VRAM signals for independent CPU and Video access
	signal vram_addr_b      : std_logic_vector(12 downto 0);  -- Video read address (port B)
	signal vram_data_b      : std_logic_vector(7 downto 0);   -- Video read data (port B)

	-- Removed DBLSCAN signals - using direct VRAM-to-TMDS instead
    --
    signal joyHBCPPFRLDU   : std_logic_vector(9 downto 0);
    signal sfc_buttons     : std_logic_vector(11 downto 0);
    --
    constant CLOCK_FREQ    : integer := 27E6;
    -- Removed debug clock signals
    signal pll_locked      : std_logic;
---------------------------------------------------------------------------------------------
component Gowin_HDMI_rPLL
    port (
        clkout: out std_logic;
        lock: out std_logic;
        clkoutd: out std_logic;
        clkin: in std_logic
    );
end component;

component Gowin_TMDS_rPLL
    port (
        clkout: out std_logic;
        lock: out std_logic;
        clkin: in std_logic
    );
end component;

component Gowin_HDMI_CLKDIV
    port (
        clkout: out std_logic;
        hclkin: in std_logic;
        resetn: in std_logic
    );
end component;

component hdmi_encoder
    port (
        clk_pixel          : in  std_logic;
        clk_tmds           : in  std_logic;
        reset_n            : in  std_logic;
        rgb_data           : in  std_logic_vector(23 downto 0);
        hsync              : in  std_logic;
        vsync              : in  std_logic;
        de                 : in  std_logic;
        audio_sample_left  : in  std_logic_vector(15 downto 0);
        audio_sample_right : in  std_logic_vector(15 downto 0);
        hdmi_tx_clk_p      : out std_logic;
        hdmi_tx_clk_n      : out std_logic;
        hdmi_tx_p          : out std_logic_vector(2 downto 0);
        hdmi_tx_n          : out std_logic_vector(2 downto 0)
    );
end component;

-- hdmi_timing component removed - using si_vram_to_tmds_portrait480 timing directly

-- Removed test pattern component

component si_vram_to_tmds_portrait480
    generic (
        LSB_LEFT : boolean := false;  -- Match entity default
        PIPE_LAT : natural := 2
    );
    port (
        pixclk    : in  std_logic;
        resetn    : in  std_logic;
        vram_addr : out std_logic_vector(15 downto 0);
        vram_q    : in  std_logic_vector(7 downto 0);
        r         : out std_logic_vector(7 downto 0);
        g         : out std_logic_vector(7 downto 0);
        b         : out std_logic_vector(7 downto 0);
        hsync     : out std_logic;
        vsync     : out std_logic;
        de        : out std_logic
    );
end component;

----------------------------------------------------------------------------------------------
    begin

    reset <= not I_RESET;

    -- Connect both S2 button and SFC controller to game controls
    -- joyHBCPPFRLDU bit assignments:
    -- 9: Fire2, 8: Fire, 7: Coin, 6: Sel2Player, 5: Sel1Player, 4: Fire, 3: Right, 2: Left, 1: Down, 0: Up
    --
    -- SFC Controller Mapping (active-low, 0 = pressed):
    -- Fire: B button (bit 0) and A button (bit 8)
    -- Movement: D-pad Left (bit 6), Right (bit 7), Up (bit 4), Down (bit 5)
    -- Insert Coin: Select button (bit 2) → joyHBCPPFRLDU(7)
    -- Start 1P/2P: Start button (bit 3) → joyHBCPPFRLDU(5) and joyHBCPPFRLDU(6)
    joyHBCPPFRLDU <= (
        9 => not sfc_buttons(8),   -- A button -> Fire2
        8 => not sfc_buttons(0),   -- B button -> Fire
        7 => not S2_BUTTON or not sfc_buttons(2), -- S2 button or SELECT -> Insert Coin
        6 => not sfc_buttons(3),   -- START -> Start 2P Game (Sel2Player)
        5 => not sfc_buttons(3),   -- START -> Start 1P Game (Sel1Player)
        4 => not sfc_buttons(0),   -- B button -> Fire (backup)
        3 => not sfc_buttons(7),   -- D-pad RIGHT -> Move Right
        2 => not sfc_buttons(6),   -- D-pad LEFT -> Move Left
        1 => not sfc_buttons(5),   -- D-pad DOWN -> Down (unused in SI)
        0 => not sfc_buttons(4)    -- D-pad UP -> Up (unused in SI)
    );
    pll_locked <= '1';
----------------------------------------------------------------------------------------------
-- System clocks for game logic
clocks: Gowin_HDMI_rPLL
    port map (
        clkout => clock_20,
        lock => pll_locked,
        clkoutd => clock_10,
        clkin => Clock_27
    );

-- TMDS clock for HDMI output (126 MHz)
tmds_clocks: Gowin_TMDS_rPLL
    port map (
        clkout => clock_tmds,
        lock => open,
        clkin => Clock_27
    );

-- Generate pixel clock from TMDS clock (126 MHz / 5 = 25.2 MHz) using Gowin CLKDIV
pixel_clk_div: Gowin_HDMI_CLKDIV
    port map (
        clkout => clock_pixel,
        hclkin => clock_tmds,
        resetn => I_RESET
    );
----------------------------------------------------------------------------------------------
	DIP <= "00000000";
----------------------------------------------------------------------------------------------
	core : entity work.invaders
		port map(
			Rst_n      => I_RESET,
			Clk        => clock_10,
			MoveLeft   => not joyHBCPPFRLDU(2),
			MoveRight  => not joyHBCPPFRLDU(3),
			Coin       => joyHBCPPFRLDU(7),
			Sel1Player => joyHBCPPFRLDU(5),
			Sel2Player => joyHBCPPFRLDU(6),
			Fire       => not joyHBCPPFRLDU(8),
			DIP        => DIP,
			RDB        => RDB,
			IB         => IB,
			RWD        => RWD,
			RAB        => RAB,
			AD         => AD,
			SoundCtrl3 => SoundCtrl3,
			SoundCtrl5 => SoundCtrl5,
			Rst_n_s    => Rst_n_s,
			RWE_n      => RWE_n,
			Video      => Video,
			HSync      => HSync,
			VSync      => VSync
			);
--------------------------------------------------------------------------
-- Rom
	u_rom : entity work.invaders_rom
	  port map (
		clk         => clock_10,
		addr        => AD(12 downto 0),
		data        => rom_data_0
		);

	p_rom_data : process(AD, rom_data_0) --, rom_data_1)
	begin
	  IB <= (others => '0');
	  case AD(14) is
		when '0' => IB <= rom_data_0;
		when others => null;
	  end case;
	end process;
----------------------------------------------------------------------------------------
-- Ram

	ram_we <= not RWE_n;

	-- Dual-port RAMs with independent clocks for CPU and Video access
	rams : for i in 0 to 3 generate

u_dpram : entity work.dpram
generic map (
	addr_width_g => 13,
	data_width_g => 2
)
port map (
	-- Port A: CPU access (10 MHz)
	clock_a   => clock_10,
	enable_a  => '1',
	wren_a    => ram_we,
	address_a => RAB,
	data_a    => RWD((i*2)+1 downto (i*2)),
	q_a       => RDB((i*2)+1 downto (i*2)),

	-- Port B: Video access (25.2 MHz pixel clock)
	clock_b   => clock_pixel,
	enable_b  => '1',
	wren_b    => '0',  -- Video is read-only
	address_b => vram_addr_b,
	data_b    => "00", -- Not used for read-only port
	q_b       => vram_data_b((i*2)+1 downto (i*2))
);
	end generate;

-- VRAM video read port (Port B) address generation and data reconstruction
-- Convert 16-bit VRAM address from TMDS module to 13-bit RAM address
-- Space Invaders VRAM: 0x2400-0x3FFF (7168 bytes) maps to RAM 0x0400-0x1FFF
process(clock_pixel)
    variable vram_offset : unsigned(15 downto 0);
begin
    if rising_edge(clock_pixel) then
        -- VRAM region 0x2400-0x3FFF maps to RAM addresses 0x0400-0x1FFF (13-bit)
        if unsigned(vram_video_addr) >= 16#2400# and unsigned(vram_video_addr) <= 16#3FFF# then
            -- Calculate offset from VRAM base and map to RAM address space
            vram_offset := unsigned(vram_video_addr) - 16#2000#;
            -- Ensure we stay within 13-bit address space (0x1FFF max)
            if vram_offset <= 16#1FFF# then
                vram_addr_b <= std_logic_vector(vram_offset(12 downto 0));
            else
                vram_addr_b <= (others => '0');  -- Clamp overflow addresses
            end if;
        else
            vram_addr_b <= (others => '0');  -- Default to 0 for out-of-range addresses
        end if;
    end if;
end process;

-- VRAM data is automatically available from dual-port RAM Port B output (vram_data_b)
-- Connect reconstructed 8-bit data to VRAM-to-TMDS module
vram_video_data <= vram_data_b;

-----------------------------------------------------------------------------------------
-- Glue

	process (Rst_n_s, clock_10)
		variable cnt : unsigned(3 downto 0);
	begin
		if Rst_n_s = '0' then
			cnt := "0000";
			Tick1us <= '0';
		elsif clock_10'event and clock_10 = '1' then
			Tick1us <= '0';
			if cnt = 9 then
				Tick1us <= '1';
				cnt := "0000";
			else
				cnt := cnt + 1;
			end if;
		end if;
	end process;
-----------------------------------------------------------------------------------------
-- Scanlines control removed - not used with direct VRAM processing
-----------------------------------------------------------------------------------------
-- Video Output

  -- Overlay process removed - color processing now handled in si_vram_to_tmds_portrait480
--------------------------------------------------------------------------------
  -- Video output process removed - color processing now handled in si_vram_to_tmds_portrait480
---------------------------------------------------------------------------------
  -- DBLSCAN component removed - using direct VRAM-to-TMDS video generation instead
  -- This provides better performance and eliminates the missing component warning
---------------------------------------------------------------------------------
  -- HDMI timing provided by si_vram_to_tmds_portrait480 (proper 640x480@60Hz VIC-1)

  -- 48 kHz audio sample rate generation for HDMI IEC-60958 compliance
  -- 25,200,000 Hz / 48,000 Hz = 525 (exact division)
  audio_sample_proc: process(clock_pixel, I_RESET)
  begin
    if I_RESET = '0' then
      audio_sample_counter <= (others => '0');
      audio_sample_tick <= '0';
    elsif rising_edge(clock_pixel) then
      if audio_sample_counter = AUDIO_SAMPLE_DIV - 1 then
        audio_sample_counter <= (others => '0');
        audio_sample_tick <= '1';
      else
        audio_sample_counter <= audio_sample_counter + 1;
        audio_sample_tick <= '0';
      end if;
    end if;
  end process;

  -- Sample and hold mono audio at 48 kHz for proper HDMI audio embedding
  audio_mono_hold_proc: process(clock_pixel, I_RESET)
  begin
    if I_RESET = '0' then
      audio_mono_reg <= (others => '0');
    elsif rising_edge(clock_pixel) then
      if audio_sample_tick = '1' then
        -- Sample mono game audio at exactly 48 kHz with volume boost
        -- Shift 8-bit audio to upper bits for maximum HDMI volume
        audio_mono_reg <= Audio & x"00";
      end if;
    end if;
  end process;

  -- Removed test pattern generator

  -- VRAM-to-TMDS direct video generator
  u_vram_tmds: si_vram_to_tmds_portrait480
    generic map (
        LSB_LEFT => true,
        PIPE_LAT => 2
    )
    port map (
        pixclk    => clock_pixel,
        resetn    => I_RESET,
        vram_addr => vram_video_addr,
        vram_q    => vram_video_data,
        r         => vram_tmds_r,
        g         => vram_tmds_g,
        b         => vram_tmds_b,
        hsync     => vram_tmds_hsync,
        vsync     => vram_tmds_vsync,
        de        => vram_tmds_de
    );

  -- HDMI encoder instantiation
  -- Direct VRAM video generation
  hdmi_rgb <= vram_tmds_r & vram_tmds_g & vram_tmds_b; -- Direct VRAM with built-in Space Invaders color processing

  u_hdmi: hdmi_encoder
    port map (
        clk_pixel          => clock_pixel,
        clk_tmds           => clock_tmds,
        reset_n            => I_RESET,
        rgb_data           => hdmi_rgb,
        hsync              => vram_tmds_hsync,
        vsync              => vram_tmds_vsync,
        de                 => vram_tmds_de,
        audio_sample_left  => audio_mono_reg,   -- Mono audio to left channel
        audio_sample_right => audio_mono_reg,   -- Mono audio to right channel
        hdmi_tx_clk_p      => hdmi_tx_clk_p,
        hdmi_tx_clk_n      => hdmi_tx_clk_n,
        hdmi_tx_p          => hdmi_tx_p,
        hdmi_tx_n          => hdmi_tx_n
    );
---------------------------------------------------------------------------------
  u_audio : entity work.invaders_audio
	port map (
	  Clk => clock_10,
	  P3  => SoundCtrl3,
	  P5  => SoundCtrl5,
	  Aud => Audio
	  );

-- SFC Controller interface
u_sfc : entity work.sfc_controller
	port map (
		clk         => clock_10,
		reset       => reset,
		sfc_latch   => SFC_LATCH,
		sfc_clk     => SFC_CLK,
		sfc_data    => SFC_DATA,
		buttons     => sfc_buttons
	);

  -- PWM audio output for better quality than simple 1-bit
  -- 8-bit PWM at ~78kHz for good audio reproduction
  pwm_audio_proc: process(clock_10, reset)
    variable pwm_counter : unsigned(7 downto 0) := (others => '0');
  begin
    if reset = '1' then
      pwm_counter := (others => '0');
      O_AUDIO <= '0';
    elsif rising_edge(clock_10) then
      pwm_counter := pwm_counter + 1;
      if pwm_counter < unsigned(Audio) then
        O_AUDIO <= '1';
      else
        O_AUDIO <= '0';
      end if;
    end if;
  end process;
  -- LEDs turned off - no debug output
  led <= (others => '0');

----------------------------------------------------------------------------------
end;