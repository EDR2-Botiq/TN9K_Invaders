-------------------------------------------------------------------------------
-- HDMI Encoder - True HDMI with TMDS and Differential Signaling
-- Implements proper HDMI encoding with OSER10 serializers and ELVDS_OBUF
-- For Tang Nano 9K (GW1NR-9C)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hdmi_encoder is
    port (
        -- Clocks
        clk_pixel     : in  std_logic;                      -- 25.2 MHz pixel clock
        clk_tmds      : in  std_logic;                      -- 126 MHz TMDS clock (DDR = 252 MHz effective)
        reset_n       : in  std_logic;                      -- Active low reset

        -- Video inputs
        rgb_data      : in  std_logic_vector(23 downto 0);  -- RGB data (8:8:8)
        hsync         : in  std_logic;                      -- Horizontal sync
        vsync         : in  std_logic;                      -- Vertical sync
        de            : in  std_logic;                      -- Data enable

        -- HDMI differential outputs
        hdmi_tx_clk_p : out std_logic;                      -- TMDS clock positive
        hdmi_tx_clk_n : out std_logic;                      -- TMDS clock negative
        hdmi_tx_p     : out std_logic_vector(2 downto 0);   -- TMDS data positive [2:0] = [R:G:B]
        hdmi_tx_n     : out std_logic_vector(2 downto 0)    -- TMDS data negative [2:0] = [R:G:B]
    );
end entity hdmi_encoder;

architecture rtl of hdmi_encoder is

    -- Component declarations
    component tmds_encoder
        port (
            clk       : in  std_logic;
            reset_n   : in  std_logic;
            data      : in  std_logic_vector(7 downto 0);
            c0        : in  std_logic;
            c1        : in  std_logic;
            de        : in  std_logic;
            q_out     : out std_logic_vector(9 downto 0)
        );
    end component;

    component OSER10
        generic (
            GSREN : string := "false";
            LSREN : string := "true"
        );
        port (
            Q      : out std_logic;
            D0, D1, D2, D3, D4, D5, D6, D7, D8, D9 : in std_logic;
            PCLK   : in std_logic;
            FCLK   : in std_logic;
            RESET  : in std_logic
        );
    end component;

    component ELVDS_OBUF
        port (
            I  : in  std_logic;
            O  : out std_logic;
            OB : out std_logic
        );
    end component;

    -- Internal signals
    signal tmds_red    : std_logic_vector(9 downto 0);
    signal tmds_green  : std_logic_vector(9 downto 0);
    signal tmds_blue   : std_logic_vector(9 downto 0);
    signal tmds_clock  : std_logic_vector(9 downto 0);

    signal serial_red   : std_logic;
    signal serial_green : std_logic;
    signal serial_blue  : std_logic;
    signal serial_clk   : std_logic;

    signal reset_p      : std_logic;

begin

    -- Convert active-low reset to active-high for OSER10
    reset_p <= not reset_n;

    -- TMDS Clock pattern (alternating 5 zeros and 5 ones)
    tmds_clock <= "0000011111";

    -- TMDS Encoders for RGB channels
    tmds_encoder_red : tmds_encoder
        port map (
            clk     => clk_pixel,
            reset_n => reset_n,
            data    => rgb_data(23 downto 16),  -- Red channel
            c0      => '0',                     -- No control on red
            c1      => '0',                     -- No control on red
            de      => de,
            q_out   => tmds_red
        );

    tmds_encoder_green : tmds_encoder
        port map (
            clk     => clk_pixel,
            reset_n => reset_n,
            data    => rgb_data(15 downto 8),   -- Green channel
            c0      => '0',                     -- No control on green
            c1      => '0',                     -- No control on green
            de      => de,
            q_out   => tmds_green
        );

    tmds_encoder_blue : tmds_encoder
        port map (
            clk     => clk_pixel,
            reset_n => reset_n,
            data    => rgb_data(7 downto 0),    -- Blue channel
            c0      => hsync,                   -- Hsync encoded in blue
            c1      => vsync,                   -- Vsync encoded in blue
            de      => de,
            q_out   => tmds_blue
        );

    -- OSER10 Serializers (10:1 parallel to serial conversion)
    oser_red : OSER10
        generic map (
            GSREN => "false",
            LSREN => "true"
        )
        port map (
            Q     => serial_red,
            D0    => tmds_red(0),
            D1    => tmds_red(1),
            D2    => tmds_red(2),
            D3    => tmds_red(3),
            D4    => tmds_red(4),
            D5    => tmds_red(5),
            D6    => tmds_red(6),
            D7    => tmds_red(7),
            D8    => tmds_red(8),
            D9    => tmds_red(9),
            PCLK  => clk_pixel,
            FCLK  => clk_tmds,
            RESET => reset_p
        );

    oser_green : OSER10
        generic map (
            GSREN => "false",
            LSREN => "true"
        )
        port map (
            Q     => serial_green,
            D0    => tmds_green(0),
            D1    => tmds_green(1),
            D2    => tmds_green(2),
            D3    => tmds_green(3),
            D4    => tmds_green(4),
            D5    => tmds_green(5),
            D6    => tmds_green(6),
            D7    => tmds_green(7),
            D8    => tmds_green(8),
            D9    => tmds_green(9),
            PCLK  => clk_pixel,
            FCLK  => clk_tmds,
            RESET => reset_p
        );

    oser_blue : OSER10
        generic map (
            GSREN => "false",
            LSREN => "true"
        )
        port map (
            Q     => serial_blue,
            D0    => tmds_blue(0),
            D1    => tmds_blue(1),
            D2    => tmds_blue(2),
            D3    => tmds_blue(3),
            D4    => tmds_blue(4),
            D5    => tmds_blue(5),
            D6    => tmds_blue(6),
            D7    => tmds_blue(7),
            D8    => tmds_blue(8),
            D9    => tmds_blue(9),
            PCLK  => clk_pixel,
            FCLK  => clk_tmds,
            RESET => reset_p
        );

    oser_clk : OSER10
        generic map (
            GSREN => "false",
            LSREN => "true"
        )
        port map (
            Q     => serial_clk,
            D0    => tmds_clock(0),
            D1    => tmds_clock(1),
            D2    => tmds_clock(2),
            D3    => tmds_clock(3),
            D4    => tmds_clock(4),
            D5    => tmds_clock(5),
            D6    => tmds_clock(6),
            D7    => tmds_clock(7),
            D8    => tmds_clock(8),
            D9    => tmds_clock(9),
            PCLK  => clk_pixel,
            FCLK  => clk_tmds,
            RESET => reset_p
        );

    -- ELVDS_OBUF Differential Output Buffers
    elvds_clk : ELVDS_OBUF
        port map (
            I  => serial_clk,
            O  => hdmi_tx_clk_p,
            OB => hdmi_tx_clk_n
        );

    elvds_red : ELVDS_OBUF
        port map (
            I  => serial_red,
            O  => hdmi_tx_p(2),     -- Red channel
            OB => hdmi_tx_n(2)
        );

    elvds_green : ELVDS_OBUF
        port map (
            I  => serial_green,
            O  => hdmi_tx_p(1),     -- Green channel
            OB => hdmi_tx_n(1)
        );

    elvds_blue : ELVDS_OBUF
        port map (
            I  => serial_blue,
            O  => hdmi_tx_p(0),     -- Blue channel
            OB => hdmi_tx_n(0)
        );

end architecture rtl;