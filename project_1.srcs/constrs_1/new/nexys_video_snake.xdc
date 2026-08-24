## Nexys Video constraints for the Snake / HDMI project
## Board: Digilent Nexys Video (Artix-7 XC7A200T-1SBG484C)

## System clock 100 MHz
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS33} [get_ports sysclk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports sysclk]

## Buttons
set_property -dict {PACKAGE_PIN B22 IOSTANDARD LVCMOS12} [get_ports btnc]
set_property -dict {PACKAGE_PIN D22 IOSTANDARD LVCMOS12} [get_ports btnd]
set_property -dict {PACKAGE_PIN C22 IOSTANDARD LVCMOS12} [get_ports btnl]
set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS12} [get_ports btnr]
set_property -dict {PACKAGE_PIN F15 IOSTANDARD LVCMOS12} [get_ports btnu]

## LEDs (score display)
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS25} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS25} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS25} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS25} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS25} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS25} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS25} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN Y13 IOSTANDARD LVCMOS25} [get_ports {led[7]}]

## HDMI OUT (direct TMDS from FPGA - no external transmitter chip on TX side)
set_property -dict {PACKAGE_PIN AA4 IOSTANDARD LVCMOS33} [get_ports hdmi_tx_cec]
set_property -dict {PACKAGE_PIN U1 IOSTANDARD TMDS_33} [get_ports hdmi_tx_clk_n]
set_property -dict {PACKAGE_PIN T1 IOSTANDARD TMDS_33} [get_ports hdmi_tx_clk_p]
set_property -dict {PACKAGE_PIN AB13 IOSTANDARD LVCMOS25} [get_ports hdmi_tx_hpd]
set_property -dict {PACKAGE_PIN Y1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_n[0]}]
set_property -dict {PACKAGE_PIN W1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_p[0]}]
set_property -dict {PACKAGE_PIN AB1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_n[1]}]
set_property -dict {PACKAGE_PIN AA1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_p[1]}]
set_property -dict {PACKAGE_PIN AB2 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_n[2]}]
set_property -dict {PACKAGE_PIN AB3 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_p[2]}]

## Required global settings
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## Clock domain crossing: sysclk (debounce) <-> clk_pix (game/video) is
## handled by a 2-flop synchronizer in top.v; mark it false path so timing
## closure doesn't try to meet setup/hold across the async boundary.
set_false_path -from [get_clocks sys_clk_pin] -to [get_clocks -of_objects [get_pins u_clk_dvi/mmcm_inst/CLKOUT1]]


set_property MARK_DEBUG false [get_nets hsync]
set_property MARK_DEBUG false [get_nets de]
set_property MARK_DEBUG false [get_nets vsync]
