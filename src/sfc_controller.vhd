-------------------------------------------------------------------------------
-- SFC Controller Interface for Tang Nano 9K
-- Based on the SFC Controller Documentation
--
-- This module implements a complete SFC controller interface using a 6-state
-- finite state machine to handle the serial synchronous protocol.
--
-- Features:
-- - Synchronous design clocked from single 10MHz source
-- - Enhanced 6-state machine with precise timing
-- - 12-button support with proper active-low handling
-- - Parameterized timing based on exact microsecond requirements
-- - Improved data sampling at optimal clock phase
-- - Error handling with proper reset and initialization
-- - Low resource usage optimized for GW1NR-9C
--
-- Button Mapping (active-low, 0 = pressed):
-- Bit 0:  B button
-- Bit 1:  Y button
-- Bit 2:  Select button
-- Bit 3:  Start button
-- Bit 4:  Up D-pad
-- Bit 5:  Down D-pad
-- Bit 6:  Left D-pad
-- Bit 7:  Right D-pad
-- Bit 8:  A button
-- Bit 9:  X button
-- Bit 10: L shoulder button
-- Bit 11: R shoulder button
--
-- Timing Requirements:
-- - Input clock: 10MHz (from game logic)
-- - Latch pulse width: 12µs (120 cycles @ 10MHz)
-- - Clock half-period: 6µs (60 cycles @ 10MHz)
-- - Complete read cycle: ~200µs for 16 bits
-- - Automatic continuous polling every ~16ms
--
-- Version: 1.0
-- Author: Generated for TN9K Space Invaders Project
-- Date: September 2025
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sfc_controller is
    port (
        clk         : in  std_logic;                      -- 10MHz system clock
        reset       : in  std_logic;                      -- Active-high reset
        sfc_latch  : out std_logic;                      -- Latch signal to controller
        sfc_clk    : out std_logic;                      -- Clock signal to controller
        sfc_data   : in  std_logic;                      -- Serial data from controller
        buttons     : out std_logic_vector(11 downto 0)   -- 12-bit button state output
    );
end entity sfc_controller;

architecture rtl of sfc_controller is

    -- Enhanced state machine with separated clock phases
    type state_type is (IDLE, LATCH_HIGH, LATCH_LOW, CLK_HIGH, CLK_LOW, DONE);
    signal state : state_type := IDLE;

    -- Parameterized timing constants (10MHz clock)
    constant CLK_HZ : integer := 10_000_000;
    constant T_LATCH_US : integer := 12;  -- Latch pulse duration
    constant T_HALF_US : integer := 6;    -- Clock half-period
    constant LATCH_CYCLES : integer := (CLK_HZ / 1_000_000) * T_LATCH_US;  -- 120 cycles
    constant HALF_CYCLES : integer := (CLK_HZ / 1_000_000) * T_HALF_US;    -- 60 cycles
    constant POLL_CYCLES : integer := CLK_HZ / 60;  -- ~16.7ms polling period

    -- Internal signals with enhanced timing
    signal timer : integer range 0 to POLL_CYCLES-1 := 0;
    signal bit_counter : integer range 0 to 15 := 0;
    signal shift_reg : std_logic_vector(15 downto 0) := (others => '1');
    signal button_reg : std_logic_vector(11 downto 0) := (others => '1');
    signal poll_counter : integer range 0 to POLL_CYCLES-1 := 0;

    -- Data signal processing
    signal sfc_data_sync : std_logic := '1';  -- Synchronized input
    signal data_active_high : std_logic := '0';  -- Inverted for active-high processing

    -- Internal clock and latch signals
    signal sfc_clk_int : std_logic := '0';
    signal sfc_latch_int : std_logic := '0';

begin

    -- Output assignments
    sfc_clk <= sfc_clk_int;
    sfc_latch <= sfc_latch_int;
    buttons <= button_reg;

    -- Input signal conditioning
    data_active_high <= not sfc_data_sync;  -- Convert active-low to active-high

    -- Enhanced controller state machine with precise timing
    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            timer <= 0;
            bit_counter <= 0;
            shift_reg <= (others => '1');
            button_reg <= (others => '1');
            poll_counter <= 0;
            sfc_clk_int <= '1';  -- Idle high
            sfc_latch_int <= '0';
            sfc_data_sync <= '1';

        elsif rising_edge(clk) then
            -- Synchronize input data
            sfc_data_sync <= sfc_data;

            case state is

                when IDLE =>
                    -- Initialize for new read cycle
                    sfc_clk_int <= '1';  -- Clock idle high
                    sfc_latch_int <= '0';
                    bit_counter <= 0;
                    timer <= 0;

                    -- Auto-poll every ~16.7ms
                    if poll_counter >= POLL_CYCLES-1 then
                        poll_counter <= 0;
                        state <= LATCH_HIGH;
                        sfc_latch_int <= '1';  -- Start latch
                    else
                        poll_counter <= poll_counter + 1;
                    end if;

                when LATCH_HIGH =>
                    -- Hold latch high for precise duration
                    sfc_latch_int <= '1';
                    sfc_clk_int <= '1';

                    if timer >= LATCH_CYCLES-1 then
                        timer <= 0;
                        sfc_latch_int <= '0';
                        sfc_clk_int <= '0';  -- Start with clock low
                        state <= LATCH_LOW;
                    else
                        timer <= timer + 1;
                    end if;

                when LATCH_LOW =>
                    -- Short low phase, then sample first bit
                    sfc_latch_int <= '0';
                    sfc_clk_int <= '0';

                    if timer >= HALF_CYCLES-1 then
                        timer <= 0;
                        -- Sample first bit (B button) immediately
                        shift_reg(0) <= data_active_high;
                        sfc_clk_int <= '1';  -- Rising edge for next bit
                        bit_counter <= 1;   -- Start from bit 1
                        state <= CLK_HIGH;
                    else
                        timer <= timer + 1;
                    end if;

                when CLK_HIGH =>
                    -- Clock high phase - prepare for sampling
                    sfc_clk_int <= '1';

                    if timer >= HALF_CYCLES-1 then
                        timer <= 0;
                        -- Sample data at end of high phase for stable timing
                        if bit_counter <= 15 then
                            shift_reg(bit_counter) <= data_active_high;
                        end if;
                        sfc_clk_int <= '0';  -- Go to low phase
                        state <= CLK_LOW;
                    else
                        timer <= timer + 1;
                    end if;

                when CLK_LOW =>
                    -- Clock low phase - prepare for next bit
                    sfc_clk_int <= '0';

                    if timer >= HALF_CYCLES-1 then
                        timer <= 0;
                        if bit_counter >= 15 then
                            -- All 16 bits read
                            sfc_clk_int <= '1';  -- Return to idle high
                            state <= DONE;
                        else
                            -- Next bit
                            bit_counter <= bit_counter + 1;
                            sfc_clk_int <= '1';  -- Rising edge
                            state <= CLK_HIGH;
                        end if;
                    else
                        timer <= timer + 1;
                    end if;

                when DONE =>
                    -- Process button data with proper bit extraction
                    sfc_clk_int <= '1';  -- Idle high
                    sfc_latch_int <= '0';

                    -- Extract 12 button bits from shift register
                    -- Controller data is already converted to active-high
                    -- Output as active-low for game compatibility
                    button_reg <= not shift_reg(11 downto 0);

                    -- Return to idle for next polling cycle
                    state <= IDLE;
                    poll_counter <= 0;

                when others =>
                    state <= IDLE;

            end case;
        end if;
    end process;

end architecture rtl;