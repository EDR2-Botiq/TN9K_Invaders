-------------------------------------------------------------------------------
-- Sigma-Delta DAC for Space Invaders Audio
-- 2nd Order Sigma-Delta Modulator for high-quality audio output
-- Provides better SNR and easier filtering than PWM
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

entity sigma_delta_dac is
    generic (
        WIDTH : integer := 8  -- Input data width (8-bit audio)
    );
    port (
        clk       : in  std_logic;  -- System clock (higher is better, ~20MHz)
        reset     : in  std_logic;
        data_in   : in  std_logic_vector(WIDTH-1 downto 0);  -- Audio data input
        dac_out   : out std_logic   -- 1-bit sigma-delta output
    );
end sigma_delta_dac;

architecture behavioral of sigma_delta_dac is
    -- 2nd order sigma-delta modulator signals
    -- Using extra bits for accumulator to prevent overflow
    constant ACC_WIDTH : integer := WIDTH + 4;  -- 12 bits for 8-bit input

    signal data_extended : std_logic_vector(ACC_WIDTH-1 downto 0);
    signal accumulator1  : std_logic_vector(ACC_WIDTH-1 downto 0) := (others => '0');
    signal accumulator2  : std_logic_vector(ACC_WIDTH-1 downto 0) := (others => '0');
    signal feedback      : std_logic_vector(ACC_WIDTH-1 downto 0);
    signal delta_out     : std_logic := '0';

begin
    -- Extend input data to accumulator width
    -- Place input in upper bits for proper scaling
    data_extended <= data_in & conv_std_logic_vector(0, ACC_WIDTH-WIDTH);

    -- Feedback value: all '1's when output is high, all '0's when low
    feedback <= (others => '1') when delta_out = '1' else (others => '0');

    -- 2nd order sigma-delta modulator process
    process(clk, reset)
        variable delta1 : std_logic_vector(ACC_WIDTH-1 downto 0);
        variable delta2 : std_logic_vector(ACC_WIDTH-1 downto 0);
        variable sum1   : std_logic_vector(ACC_WIDTH-1 downto 0);
        variable sum2   : std_logic_vector(ACC_WIDTH-1 downto 0);
    begin
        if reset = '1' then
            accumulator1 <= (others => '0');
            accumulator2 <= (others => '0');
            delta_out <= '0';
        elsif rising_edge(clk) then
            -- First integrator stage
            -- delta1 = data_extended - feedback
            if delta_out = '1' then
                delta1 := data_extended - feedback;
            else
                delta1 := data_extended;
            end if;

            -- sum1 = accumulator1 + delta1
            sum1 := accumulator1 + delta1;
            accumulator1 <= sum1;

            -- Second integrator stage
            -- delta2 = sum1 - feedback
            if delta_out = '1' then
                delta2 := sum1 - feedback;
            else
                delta2 := sum1;
            end if;

            -- sum2 = accumulator2 + delta2
            sum2 := accumulator2 + delta2;
            accumulator2 <= sum2;

            -- Comparator (quantizer)
            -- Output high if accumulator2 is in upper half
            if accumulator2(ACC_WIDTH-1) = '0' then  -- Check MSB (sign bit)
                delta_out <= '1';
            else
                delta_out <= '0';
            end if;
        end if;
    end process;

    -- Output assignment
    dac_out <= delta_out;

end behavioral;