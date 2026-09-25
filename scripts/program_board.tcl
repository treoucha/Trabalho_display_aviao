set root [file normalize [file join [file dirname [info script]] ..]]
set bitstream [file join $root build vivado reticula.runs impl_1 top_reticula.bit]
if {![file exists $bitstream]} { error "Gere o bitstream antes de programar a placa" }
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set devices [get_hw_devices -filter {PART == "xc7a100t"}]
if {[llength $devices] != 1} { error "Esperada uma única FPGA xc7a100t conectada" }
set device [lindex $devices 0]
current_hw_device $device
refresh_hw_device $device
set_property PROGRAM.FILE $bitstream $device
program_hw_devices $device
refresh_hw_device $device
puts "PROGRAM_DONE=[get_property REGISTER.IR.BIT5_DONE $device]"
close_hw_manager
