## ============================================================
## NEXYS A7-100T
## Clock 100 MHz
## ============================================================

set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

create_clock -add -name sys_clk_pin -period 10.000 \
    -waveform {0 5} [get_ports clk]


## ============================================================
## VGA RED
## ============================================================

set_property PACKAGE_PIN A3 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN B4 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN C5 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN A4 [get_ports {vga_r[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[*]}]


## ============================================================
## VGA GREEN
## ============================================================

set_property PACKAGE_PIN C6 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN A5 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN B6 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN A6 [get_ports {vga_g[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[*]}]


## ============================================================
## VGA BLUE
## ============================================================

set_property PACKAGE_PIN B7 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN C7 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN D7 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN D8 [get_ports {vga_b[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[*]}]


## ============================================================
## VGA SYNC
## ============================================================

set_property PACKAGE_PIN B11 [get_ports vga_hsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hsync]

set_property PACKAGE_PIN B12 [get_ports vga_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vsync]

## ============================================================
## PIN SETS JA
## ============================================================

set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { JA[1] }]; #IO_L20N_T3_A19_15 Sch=ja[1]
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { JA[2] }]; #IO_L21N_T3_DQS_A18_15 Sch=ja[2]
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { JA[3] }]; #IO_L21P_T3_DQS_15 Sch=ja[3]
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { JA[4] }]; #IO_L18N_T2_A23_15 Sch=ja[4]
set_property -dict { PACKAGE_PIN D17   IOSTANDARD LVCMOS33 } [get_ports { JA[7] }]; #IO_L16N_T2_A27_15 Sch=ja[7]
set_property -dict { PACKAGE_PIN E17   IOSTANDARD LVCMOS33 } [get_ports { JA[8] }]; #IO_L16P_T2_A28_15 Sch=ja[8]
set_property -dict { PACKAGE_PIN F18   IOSTANDARD LVCMOS33 } [get_ports { JA[9] }]; #IO_L22N_T3_A16_15 Sch=ja[9]
set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { JA[10] }]; #IO_L22P_T3_A17_15 Sch=ja[10]
