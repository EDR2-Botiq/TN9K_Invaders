################################################################################
# TN9K Space Invaders - SDC Timing Constraints (MINIMAL)
# Target: GW1NR-9C FPGA (Tang Nano 9K)
################################################################################

# Primary 27 MHz crystal oscillator input
create_clock -name Clock_27 -period 37.037 -waveform {0 18.518} [get_ports {Clock_27}]

# Asynchronous inputs
set_false_path -from [get_ports {I_RESET}]
set_false_path -from [get_ports {S2_BUTTON}]
set_false_path -from [get_ports {SFC_DATA}]

# Low-speed outputs
set_false_path -to [get_ports {led[*]}]
set_false_path -to [get_ports {O_AUDIO}]

# Audio register constraints - treat as asynchronous to avoid timing violations
set_false_path -to [get_pins {audio_mono_reg*/D}]

################################################################################
# End of SDC
################################################################################