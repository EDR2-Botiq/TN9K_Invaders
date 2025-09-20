-------------------------------------------------------------------------------
--                        Space Invaders - Tang Nano 9k
--                     For Original Code  (see notes below)
--
--               Based on pinballwizz/TangNano9K-Invaders
--           Adapted for HDMI output and SNES controller
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
		-- HDMI differential outputs
		hdmi_tx_clk_p     : out   std_logic;
		hdmi_tx_clk_n     : out   std_logic;
		hdmi_tx_p         : out   std_logic_vector(2 downto 0);
		hdmi_tx_n         : out   std_logic_vector(2 downto 0);
		O_AUDIO_L         : out   std_logic;
		O_AUDIO_R         : out   std_logic;
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
	signal VideoRGB        : std_logic_vector(2 downto 0);
	signal VideoRGB_X2     : std_logic_vector(7 downto 0);
	signal HSync           : std_logic;
	signal VSync           : std_logic;
	signal HSync_X2        : std_logic;
	signal VSync_X2        : std_logic;
	signal scanlines       : std_logic;
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
	signal HCnt            : std_logic_vector(11 downto 0);
	signal VCnt            : std_logic_vector(11 downto 0);
	signal HSync_t1        : std_logic;
	signal Overlay_G1      : boolean;
	signal Overlay_G2      : boolean;
	signal Overlay_R1      : boolean;
	signal Overlay_G1_VCnt : boolean;
    --
	signal Audio           : std_logic_vector(7 downto 0);
	signal AudioPWM        : std_logic;
	-- HDMI signals
	signal hdmi_rgb        : std_logic_vector(23 downto 0);
	signal hdmi_de         : std_logic;
	signal hdmi_hsync      : std_logic;
	signal hdmi_vsync      : std_logic;
	signal hdmi_h_count    : unsigned(9 downto 0);
	signal hdmi_v_count    : unsigned(9 downto 0);
	signal hdmi_active     : std_logic;
	-- Test pattern signals
	signal test_pattern_r  : std_logic_vector(7 downto 0);
	signal test_pattern_g  : std_logic_vector(7 downto 0);
	signal test_pattern_b  : std_logic_vector(7 downto 0);
	signal use_test_pattern : std_logic := '0';  -- Set to '1' for test mode, '0' for game

	-- VRAM-to-TMDS signals
	signal vram_video_addr  : std_logic_vector(15 downto 0);
	signal vram_video_data  : std_logic_vector(7 downto 0);
	signal vram_tmds_r      : std_logic_vector(7 downto 0);
	signal vram_tmds_g      : std_logic_vector(7 downto 0);
	signal vram_tmds_b      : std_logic_vector(7 downto 0);
	signal vram_tmds_hsync  : std_logic;
	signal vram_tmds_vsync  : std_logic;
	signal vram_tmds_de     : std_logic;
	signal use_vram_tmds    : std_logic := '1';  -- Set to '1' for direct VRAM, '0' for processed game with color overlay

	-- Dual-port VRAM signals for independent CPU and Video access
	signal vram_addr_b      : std_logic_vector(12 downto 0);  -- Video read address (port B)
	signal vram_data_b      : std_logic_vector(7 downto 0);   -- Video read data (port B)

	-- Enhanced dblscan with color overlay signals
	signal dblscan_rgb      : std_logic_vector(23 downto 0);  -- 24-bit RGB from dblscan
	signal dblscan_hsync    : std_logic;
	signal dblscan_vsync    : std_logic;
	signal dblscan_de       : std_logic;
    --
    signal joyHBCPPFRLDU   : std_logic_vector(9 downto 0);
    --
    constant CLOCK_FREQ    : integer := 27E6;
    signal counter_clk     : std_logic_vector(25 downto 0);
    signal clock_4hz       : std_logic;
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

component Gowin_HDMI_TMDS_rPLL
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
        clk_pixel     : in  std_logic;
        clk_tmds      : in  std_logic;
        reset_n       : in  std_logic;
        rgb_data      : in  std_logic_vector(23 downto 0);
        hsync         : in  std_logic;
        vsync         : in  std_logic;
        de            : in  std_logic;
        hdmi_tx_clk_p : out std_logic;
        hdmi_tx_clk_n : out std_logic;
        hdmi_tx_p     : out std_logic_vector(2 downto 0);
        hdmi_tx_n     : out std_logic_vector(2 downto 0)
    );
end component;

component hdmi_timing
    port (
        clk_pixel   : in  std_logic;
        reset_n     : in  std_logic;
        hsync       : out std_logic;
        vsync       : out std_logic;
        de          : out std_logic;
        h_count     : out unsigned(9 downto 0);
        v_count     : out unsigned(9 downto 0);
        active      : out std_logic
    );
end component;

component hdmi_test_pattern
    port (
        clk_pixel   : in  std_logic;
        reset_n     : in  std_logic;
        h_count     : in  unsigned(9 downto 0);
        v_count     : in  unsigned(9 downto 0);
        active      : in  std_logic;
        pattern_sel : in  std_logic_vector(2 downto 0);
        auto_cycle  : in  std_logic;
        r           : out std_logic_vector(7 downto 0);
        g           : out std_logic_vector(7 downto 0);
        b           : out std_logic_vector(7 downto 0)
    );
end component;

component si_vram_to_tmds_portrait480
    generic (
        LSB_LEFT : boolean := true;
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

    -- Connect S2 button to coin insert (active low button, so invert)
    -- joyHBCPPFRLDU bit assignments:
    -- 7: Coin, 6: Sel2Player, 5: Sel1Player, 4: Fire, 3: Right, 2: Left, 1: Down, 0: Up
    joyHBCPPFRLDU <= (7 => not S2_BUTTON, others => '0');
    pll_locked <= '1';
----------------------------------------------------------------------------------------------
-- System clocks for game logic
clocks: Gowin_HDMI_rPLL
    port map (
        clkout => clock_20,
        lock => pll_locked,
        clkoutd => clock_10,
        clkin => clock_27
    );

-- TMDS clock for HDMI output (126 MHz)
tmds_clocks: Gowin_HDMI_TMDS_rPLL
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
			Clk        => Clock_10,
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
		clk         => Clock_10,
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
	clock_a   => Clock_10,
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
process(clock_pixel)
begin
    if rising_edge(clock_pixel) then
        -- Convert 16-bit address (0x2400-0x3FFF) to 13-bit RAM address
        -- VRAM region 0x2400-0x3FFF maps to RAM addresses 0x0400-0x1FFF (13-bit)
        if unsigned(vram_video_addr) >= 16#2400# and unsigned(vram_video_addr) <= 16#3FFF# then
            -- Convert to 13-bit address space: subtract 0x2000 to get offset in RAM space
            vram_addr_b <= std_logic_vector(unsigned(vram_video_addr(12 downto 0)) - to_unsigned(16#2000#, 13));
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

	process (Rst_n_s, Clock_10)
		variable cnt : unsigned(3 downto 0);
	begin
		if Rst_n_s = '0' then
			cnt := "0000";
			Tick1us <= '0';
		elsif Clock_10'event and Clock_10 = '1' then
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
-- scanlines control

	process (Rst_n_s, Clock_10)
       begin
        if joyHBCPPFRLDU(0) = '1' then scanlines <= '0'; end if; --up arrow
        if joyHBCPPFRLDU(1) = '1' then scanlines <= '1'; end if; --down arrow
	end process;
-----------------------------------------------------------------------------------------
-- Video Output

  p_overlay : process(Rst_n_s, Clock_10)
	variable HStart : boolean;
  begin
	if Rst_n_s = '0' then
	  HCnt <= (others => '0');
	  VCnt <= (others => '0');
	  HSync_t1 <= '0';
	  Overlay_G1_VCnt <= false;
	  Overlay_G1 <= false;
	  Overlay_G2 <= false;
	  Overlay_R1 <= false;
	elsif Clock_10'event and Clock_10 = '1' then
	  HSync_t1 <= HSync;
	  HStart := (HSync_t1 = '0') and (HSync = '1');-- rising

	  if HStart then
		HCnt <= (others => '0');
	  else
		HCnt <= HCnt + "1";
	  end if;

	  if (VSync = '0') then
		VCnt <= (others => '0');
	  elsif HStart then
		VCnt <= VCnt + "1";
	  end if;

	  if HStart then
		if (Vcnt = x"1F") then
		  Overlay_G1_VCnt <= true;
		elsif (Vcnt = x"95") then
		  Overlay_G1_VCnt <= false;
		end if;
	  end if;

	  if (HCnt = x"027") and Overlay_G1_VCnt then
		Overlay_G1 <= true;
	  elsif (HCnt = x"046") then
		Overlay_G1 <= false;
	  end if;

	  if (HCnt = x"046") then
		Overlay_G2 <= true;
	  elsif (HCnt = x"0B6") then
		Overlay_G2 <= false;
	  end if;

	  if (HCnt = x"1A6") then
		Overlay_R1 <= true;
	  elsif (HCnt = x"1E6") then
		Overlay_R1 <= false;
	  end if;

	end if;
  end process;
--------------------------------------------------------------------------------
  p_video_out_comb : process(Video, Overlay_G1, Overlay_G2, Overlay_R1)
  begin
	if (Video = '0') then
	  VideoRGB  <= "000";
	else
	  if Overlay_G1 or Overlay_G2 then
		VideoRGB  <= "010";
	  elsif Overlay_R1 then
		VideoRGB  <= "100";
	  else
		VideoRGB  <= "111";
	  end if;
	end if;
  end process;
---------------------------------------------------------------------------------
  u_dblscan : entity work.DBLSCAN
	port map (
	  RGB_IN(7 downto 3) => "00000",
	  RGB_IN(2 downto 0) => VideoRGB,
	  HSYNC_IN           => HSync,
	  VSYNC_IN           => VSync,

	  RGB_OUT            => dblscan_rgb,   -- 24-bit RGB with color overlay
	  HSYNC_OUT          => dblscan_hsync,
	  VSYNC_OUT          => dblscan_vsync,
	  DE_OUT             => dblscan_de,    -- Data enable for proper timing
	  --  NOTE CLOCKS MUST BE PHASE LOCKED !!
	  CLK                => Clock_10,
	  CLK_X2             => Clock_20,
	  scanlines          => scanlines,     -- scanlines = 1 ON
	  color_overlay      => '1'            -- Enable authentic SI colors
	);
---------------------------------------------------------------------------------
  -- HDMI timing generator for proper 640x480@60Hz timing
  u_hdmi_timing: hdmi_timing
    port map (
        clk_pixel => clock_pixel,
        reset_n   => I_RESET,
        hsync     => hdmi_hsync,
        vsync     => hdmi_vsync,
        de        => hdmi_de,
        h_count   => hdmi_h_count,
        v_count   => hdmi_v_count,
        active    => hdmi_active
    );

  -- Test pattern generator (for debugging HDMI)
  u_test_pattern: hdmi_test_pattern
    port map (
        clk_pixel   => clock_pixel,
        reset_n     => I_RESET,
        h_count     => hdmi_h_count,
        v_count     => hdmi_v_count,
        active      => hdmi_active,
        pattern_sel => "001",  -- Vertical color bars
        auto_cycle  => '1',    -- Auto-cycle patterns
        r           => test_pattern_r,
        g           => test_pattern_g,
        b           => test_pattern_b
    );

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
  -- RGB data selection: test pattern, direct VRAM, or processed game video with color overlay
  hdmi_rgb <= test_pattern_r & test_pattern_g & test_pattern_b when use_test_pattern = '1' else
              vram_tmds_r & vram_tmds_g & vram_tmds_b when use_vram_tmds = '1' else
              dblscan_rgb; -- Enhanced dblscan with authentic Space Invaders color overlay

  u_hdmi: hdmi_encoder
    port map (
        clk_pixel     => clock_pixel,
        clk_tmds      => clock_tmds,
        reset_n       => I_RESET,
        rgb_data      => hdmi_rgb,
        hsync         => vram_tmds_hsync when use_vram_tmds = '1' else dblscan_hsync,
        vsync         => vram_tmds_vsync when use_vram_tmds = '1' else dblscan_vsync,
        de            => vram_tmds_de when use_vram_tmds = '1' else dblscan_de,
        hdmi_tx_clk_p => hdmi_tx_clk_p,
        hdmi_tx_clk_n => hdmi_tx_clk_n,
        hdmi_tx_p     => hdmi_tx_p,
        hdmi_tx_n     => hdmi_tx_n
    );
---------------------------------------------------------------------------------
  u_audio : entity work.invaders_audio
	port map (
	  Clk => Clock_10,
	  P3  => SoundCtrl3,
	  P5  => SoundCtrl5,
	  Aud => Audio
	  );
----------------------------------------------------------------------------------
  -- 2nd order Sigma-Delta DAC for better audio quality
  u_sigma_delta_dac : entity work.sigma_delta_dac
	generic map(
	  WIDTH => 8
	)
	port  map(
	  clk     => Clock_20,  -- Use higher clock for better oversampling
	  reset   => reset,
	  data_in => Audio,
	  dac_out => AudioPWM
	);

  O_AUDIO_L <= AudioPWM;
  O_AUDIO_R <= AudioPWM;
----------------------------------------------------------------------------------
-- debug

process(reset, clock_27)
begin
  if reset = '1' then
    clock_4hz <= '0';
    counter_clk <= (others => '0');
  else
    if rising_edge(clock_27) then
      if counter_clk = CLOCK_FREQ/8 then
        counter_clk <= (others => '0');
        clock_4hz <= not clock_4hz;
        led(5 downto 0) <= not AD(9 downto 4);
      else
        counter_clk <= counter_clk + 1;
      end if;
    end if;
  end if;
end process;
----------------------------------------------------------------------------------
end;