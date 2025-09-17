################################################################################
# TN9K Space Invaders - SDC Timing Constraints (Simplified)
# Target: GW1NR-9C FPGA (Tang Nano 9K)
################################################################################

# Primary 27 MHz crystal oscillator input
create_clock -name Clock_27 -period 37.037 -waveform {0 18.518} [get_ports {Clock_27}]

# HDMI outputs are source-synchronous (self-timed differential signals)
set_false_path -to [get_ports {hdmi_tx_clk_p hdmi_tx_clk_n}]
set_false_path -to [get_ports {hdmi_tx_p[*] hdmi_tx_n[*]}]

# Reset is asynchronous
set_false_path -from [get_ports {I_RESET}]

# S2 button is asynchronous
set_false_path -from [get_ports {S2_BUTTON}]

# LED outputs are slow and non-critical
set_false_path -to [get_ports {led[*]}]

# PWM audio outputs are low-frequency and non-critical
set_false_path -to [get_ports {O_AUDIO_L O_AUDIO_R}]

################################################################################
# End of SDC File
################################################################################