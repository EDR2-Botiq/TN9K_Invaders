-- Space Invaders VRAM to HDMI converter
-- Converts 256x224 1bpp VRAM to 640x480 HDMI output with 2x scaling
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity si_vram_to_tmds_portrait480 is
  generic (
    LSB_LEFT : boolean := false;
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
end entity;

architecture rtl of si_vram_to_tmds_portrait480 is
  -- 640x480 @ 60Hz timing constants
  constant H_ACTIVE : natural := 640;
  constant H_FP     : natural := 16;
  constant H_SYNC   : natural := 96;
  constant H_BP     : natural := 48;
  constant H_BLANK  : natural := H_FP + H_SYNC + H_BP;
  constant H_TOTAL  : natural := H_ACTIVE + H_BLANK;

  constant V_ACTIVE : natural := 480;
  constant V_FP     : natural := 10;
  constant V_SYNC   : natural := 2;
  constant V_BP     : natural := 33;
  constant V_BLANK  : natural := V_FP + V_SYNC + V_BP;
  constant V_TOTAL  : natural := V_ACTIVE + V_BLANK;

  -- Content window: 2x scaled 256x224 = 512x448, centered in 640x480
  constant X_PAD    : natural := 64;
  constant Y_PAD    : natural := 16;
  constant CNT_W    : natural := 512;
  constant CNT_H    : natural := 448;

  constant VRAM_BASE : natural := 16#2400#;

  signal hcnt : unsigned(9 downto 0);
  signal vcnt : unsigned(9 downto 0);

  signal de_i  : std_logic;
  signal hs_i  : std_logic;
  signal vs_i  : std_logic;
  signal x_act : unsigned(9 downto 0);
  signal y_act : unsigned(9 downto 0);
  signal in_cnt_x : std_logic;
  signal in_cnt_y : std_logic;
  signal in_cnt   : std_logic;
  signal xin : unsigned(8 downto 0);
  signal yin : unsigned(8 downto 0);
  signal x_raw : unsigned(8 downto 0);
  signal y_raw : unsigned(8 downto 0);

  signal byte_addr_s0 : unsigned(15 downto 0);
  signal bitidx_s0    : unsigned(2 downto 0);
  signal byte_addr_s1 : unsigned(15 downto 0);
  signal bitidx_s1    : unsigned(2 downto 0);
  signal in_cnt_s1    : std_logic;
  signal px_bit_s1 : std_logic;
  signal r_s2, g_s2, b_s2 : std_logic_vector(7 downto 0);
  signal de_raw_s2        : std_logic;
  subtype delay_vec is std_logic_vector(PIPE_LAT downto 0);
  signal de_sh, hs_sh, vs_sh : delay_vec;

begin
  -- Timing generation

  process(pixclk, resetn)
  begin
    if resetn = '0' then
      hcnt <= (others => '0');
      vcnt <= (others => '0');
    elsif rising_edge(pixclk) then
      if hcnt = H_TOTAL - 1 then
        hcnt <= (others => '0');
        if vcnt = V_TOTAL - 1 then
          vcnt <= (others => '0');
        else
          vcnt <= vcnt + 1;
        end if;
      else
        hcnt <= hcnt + 1;
      end if;
    end if;
  end process;

  de_i <= '1' when (hcnt < H_ACTIVE) and (vcnt < V_ACTIVE) else '0';
  hs_i <= '0' when (hcnt >= H_ACTIVE + H_FP) and (hcnt < H_ACTIVE + H_FP + H_SYNC) else '1';
  vs_i <= '0' when (vcnt >= V_ACTIVE + V_FP) and (vcnt < V_ACTIVE + V_FP + V_SYNC) else '1';
  x_act <= hcnt when hcnt < H_ACTIVE else (others => '0');
  y_act <= vcnt when vcnt < V_ACTIVE else (others => '0');

  -- Content window detection
  in_cnt_x <= '1' when (x_act >= X_PAD) and (x_act < X_PAD + CNT_W) else '0';
  in_cnt_y <= '1' when (y_act >= Y_PAD) and (y_act < Y_PAD + CNT_H) else '0';
  in_cnt   <= in_cnt_x and in_cnt_y and de_i;

  -- Coordinate transformation
  xin <= resize((x_act - X_PAD), 9) srl 1;
  yin <= resize((y_act - Y_PAD), 9) srl 1;
  x_raw <= xin;
  y_raw <= yin;

  -- VRAM address calculation

  process(pixclk, resetn)
  begin
    if resetn = '0' then
      byte_addr_s0 <= (others => '0');
      bitidx_s0    <= (others => '0');
    elsif rising_edge(pixclk) then
      if in_cnt = '1' then
        byte_addr_s0 <= to_unsigned(VRAM_BASE, 16) + (y_raw(7 downto 0) * 32) + (x_raw(8 downto 3));
        bitidx_s0    <= x_raw(2 downto 0) - 1;
      else
        byte_addr_s0 <= (others => '0');
        bitidx_s0    <= (others => '0');
      end if;
    end if;
  end process;

  vram_addr <= std_logic_vector(byte_addr_s0);

  -- Pipeline stage S1

  process(pixclk, resetn)
  begin
    if resetn = '0' then
      byte_addr_s1 <= (others => '0');
      bitidx_s1    <= (others => '0');
      in_cnt_s1    <= '0';
    elsif rising_edge(pixclk) then
      byte_addr_s1 <= byte_addr_s0;
      bitidx_s1    <= bitidx_s0;
      in_cnt_s1    <= in_cnt;
    end if;
  end process;

  process(vram_q, bitidx_s1)
  begin
    if LSB_LEFT then
      case bitidx_s1 is
        when "000"  => px_bit_s1 <= vram_q(0);
        when "001"  => px_bit_s1 <= vram_q(1);
        when "010"  => px_bit_s1 <= vram_q(2);
        when "011"  => px_bit_s1 <= vram_q(3);
        when "100"  => px_bit_s1 <= vram_q(4);
        when "101"  => px_bit_s1 <= vram_q(5);
        when "110"  => px_bit_s1 <= vram_q(6);
        when "111"  => px_bit_s1 <= vram_q(7);
        when others => px_bit_s1 <= '0';
      end case;
    else
      case bitidx_s1 is
        when "000"  => px_bit_s1 <= vram_q(7);
        when "001"  => px_bit_s1 <= vram_q(6);
        when "010"  => px_bit_s1 <= vram_q(5);
        when "011"  => px_bit_s1 <= vram_q(4);
        when "100"  => px_bit_s1 <= vram_q(3);
        when "101"  => px_bit_s1 <= vram_q(2);
        when "110"  => px_bit_s1 <= vram_q(1);
        when "111"  => px_bit_s1 <= vram_q(0);
        when others => px_bit_s1 <= '0';
      end case;
    end if;
  end process;

  -- RGB output stage

  process(pixclk, resetn)
  begin
    if resetn = '0' then
      r_s2 <= (others => '0');
      g_s2 <= (others => '0');
      b_s2 <= (others => '0');
      de_raw_s2 <= '0';
    elsif rising_edge(pixclk) then
      de_raw_s2 <= in_cnt_s1;

      if in_cnt_s1 = '1' then
        if px_bit_s1 = '1' then
          if x_act < 160 then
            r_s2 <= (others => '1'); g_s2 <= (others => '0'); b_s2 <= (others => '0');
          elsif x_act >= 160 and x_act < 480 then
            r_s2 <= (others => '1'); g_s2 <= (others => '1'); b_s2 <= (others => '1');
          else
            r_s2 <= (others => '0'); g_s2 <= (others => '1'); b_s2 <= (others => '0');
          end if;
        else
          r_s2 <= (others => '0'); g_s2 <= (others => '0'); b_s2 <= (others => '0');
        end if;
      else
        r_s2 <= (others => '0'); g_s2 <= (others => '0'); b_s2 <= (others => '0');
      end if;
    end if;
  end process;

  -- Timing signal pipeline

  process(pixclk, resetn)
  begin
    if resetn = '0' then
      de_sh <= (others => '0');
      hs_sh <= (others => '1');
      vs_sh <= (others => '1');
    elsif rising_edge(pixclk) then
      de_sh <= de_sh(PIPE_LAT-1 downto 0) & de_i;
      hs_sh <= hs_sh(PIPE_LAT-1 downto 0) & hs_i;
      vs_sh <= vs_sh(PIPE_LAT-1 downto 0) & vs_i;
    end if;
  end process;

  -- Output assignments
  r     <= r_s2;
  g     <= g_s2;
  b     <= b_s2;
  hsync <= hs_sh(PIPE_LAT);
  vsync <= vs_sh(PIPE_LAT);
  de    <= de_sh(PIPE_LAT);

end architecture;
