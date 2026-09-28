## =========================================================
## nexys_a7_reticula.xdc
## Constraints para o projeto da retícula no Nexys A7
## Pinos conferem com o Master XDC oficial da Digilent
## para o Nexys A7-50T / A7-100T
## =========================================================

## Clock 100 MHz do board
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports { clk }]; #Sch=clk100mhz
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

# Clock de pixel gerado pelo divisor por quatro do controlador.
create_generated_clock -name pixel_clk -source [get_ports clk] -divide_by 4 [get_pins u_vga/clk25_reg/Q]

## Conector VGA
set_property -dict { PACKAGE_PIN A3  IOSTANDARD LVCMOS33 } [get_ports { VGA_R[0] }]; #Sch=vga_r[0]
set_property -dict { PACKAGE_PIN B4  IOSTANDARD LVCMOS33 } [get_ports { VGA_R[1] }]; #Sch=vga_r[1]
set_property -dict { PACKAGE_PIN C5  IOSTANDARD LVCMOS33 } [get_ports { VGA_R[2] }]; #Sch=vga_r[2]
set_property -dict { PACKAGE_PIN A4  IOSTANDARD LVCMOS33 } [get_ports { VGA_R[3] }]; #Sch=vga_r[3]

set_property -dict { PACKAGE_PIN C6  IOSTANDARD LVCMOS33 } [get_ports { VGA_G[0] }]; #Sch=vga_g[0]
set_property -dict { PACKAGE_PIN A5  IOSTANDARD LVCMOS33 } [get_ports { VGA_G[1] }]; #Sch=vga_g[1]
set_property -dict { PACKAGE_PIN B6  IOSTANDARD LVCMOS33 } [get_ports { VGA_G[2] }]; #Sch=vga_g[2]
set_property -dict { PACKAGE_PIN A6  IOSTANDARD LVCMOS33 } [get_ports { VGA_G[3] }]; #Sch=vga_g[3]

set_property -dict { PACKAGE_PIN B7  IOSTANDARD LVCMOS33 } [get_ports { VGA_B[0] }]; #Sch=vga_b[0]
set_property -dict { PACKAGE_PIN C7  IOSTANDARD LVCMOS33 } [get_ports { VGA_B[1] }]; #Sch=vga_b[1]
set_property -dict { PACKAGE_PIN D7  IOSTANDARD LVCMOS33 } [get_ports { VGA_B[2] }]; #Sch=vga_b[2]
set_property -dict { PACKAGE_PIN D8  IOSTANDARD LVCMOS33 } [get_ports { VGA_B[3] }]; #Sch=vga_b[3]

set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 } [get_ports { VGA_HS }]; #Sch=vga_hs
set_property -dict { PACKAGE_PIN B12 IOSTANDARD LVCMOS33 } [get_ports { VGA_VS }]; #Sch=vga_vs

## =========================================================
## SEN-10955 / MMA8452Q - I2C
## =========================================================

set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports { i2c_sda }]; #JA1 - SDA

# set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { JA[2] }]; #IO_L21N_T3_DQS_A18_15 Sch=ja[2]

# set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports { JA[3] }]; #IO_L21P_T3_DQS_15 Sch=ja[3]

# set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports { JA[4] }]; #IO_L18N_T2_A23_15 Sch=ja[4]

set_property -dict { PACKAGE_PIN D17 IOSTANDARD LVCMOS33 } [get_ports { i2c_scl }]; #JA7 - SCL

# set_property -dict { PACKAGE_PIN E17 IOSTANDARD LVCMOS33 } [get_ports { JA[8] }]; #IO_L16P_T2_A28_15 Sch=ja[8]

# set_property -dict { PACKAGE_PIN F18 IOSTANDARD LVCMOS33 } [get_ports { JA[9] }]; #IO_L22N_T3_A16_15 Sch=ja[9]

# set_property -dict { PACKAGE_PIN G18 IOSTANDARD LVCMOS33 } [get_ports { JA[10] }]; #IO_L22P_T3_A17_15 Sch=ja[10]

## Controles: Master XDC oficial Nexys-A7-100T, consultado em 27/09/2026.
# https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc

# Entradas manuais assíncronas: exceção somente até o primeiro estágio.

# SW12/SW13: Master XDC Nexys-A7-100T, H6/U12, ambos LVCMOS33.
set_property -dict { PACKAGE_PIN H6 IOSTANDARD LVCMOS33 } [get_ports { sw[12] }]
set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } [get_ports { sw[13] }]
set_false_path -from [get_ports {sw[12] sw[13]}] -to [get_pins -hier -filter {NAME =~ horizonte_meta_reg*/D}]
# SW14/SW15: controle simulado de roll.
# SW14/SW15: controle simulado de roll
set_property -dict { PACKAGE_PIN U11 IOSTANDARD LVCMOS33 } [get_ports {sw[14]}]
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports {sw[15]}]

set_false_path -from [get_ports {sw[14] sw[15]}] \
    -to [get_pins -hier -filter {NAME =~ roll_meta_reg*/D}]


# BTNU / BTND: controle manual do heading
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports { btn_heading[0] }]
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { btn_heading[1] }]

# Entradas assincronas ate o primeiro estagio de sincronizacao.
set_false_path -from [get_ports {btn_heading[*]}] \
    -to [get_pins -hier -filter {NAME =~ u_heading/btn_meta_reg*/D}]

# SW0 seleciona NORMAL (0) / DECLUTTER (1).
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports { display_mode }]
set_false_path -from [get_ports display_mode] -to [get_pins -hier -filter {NAME =~ u_modo/modo_meta_reg/D}]

## =========================================================
## SEN-09694/barometro
## =========================================================

set_property -dict { PACKAGE_PIN H4    IOSTANDARD LVCMOS33 } [get_ports { Bin }]; #IO_L21N_T3_DQS_35 Sch=jd[1]
set_property -dict { PACKAGE_PIN H1    IOSTANDARD LVCMOS33 } [get_ports { Bout }]; #IO_L17P_T2_35 Sch=jd[2]
#set_property -dict { PACKAGE_PIN G1    IOSTANDARD LVCMOS33 } [get_ports { JD[3] }]; #IO_L17N_T2_35 Sch=jd[3]
#set_property -dict { PACKAGE_PIN G3    IOSTANDARD LVCMOS33 } [get_ports { JD[4] }]; #IO_L20N_T3_35 Sch=jd[4]
#set_property -dict { PACKAGE_PIN H2    IOSTANDARD LVCMOS33 } [get_ports { JD[7] }]; #IO_L15P_T2_DQS_35 Sch=jd[7]
#set_property -dict { PACKAGE_PIN G4    IOSTANDARD LVCMOS33 } [get_ports { JD[8] }]; #IO_L20P_T3_35 Sch=jd[8]
#set_property -dict { PACKAGE_PIN G2    IOSTANDARD LVCMOS33 } [get_ports { JD[9] }]; #IO_L15N_T2_DQS_35 Sch=jd[9]
#set_property -dict { PACKAGE_PIN F3    IOSTANDARD LVCMOS33 } [get_ports { JD[10] }]; #IO_L13N_T2_MRCC_35 Sch=jd[10]


