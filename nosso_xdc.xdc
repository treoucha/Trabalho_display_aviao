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
