set root [file normalize [file join [file dirname [info script]] ..]]
create_project reticula [file join $root build vivado] -part xc7a100tcsg324-1 -force
add_files [glob [file join $root rtl *.v]]
add_files -fileset constrs_1 [file join $root constraints nexys_a7_reticula.xdc]
set_property top top_reticula [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "Síntese não concluída" }
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { error "Implementação não concluída" }
open_run impl_1
report_timing_summary -file [file join $root build timing_summary.rpt]
report_utilization -file [file join $root build utilization.rpt]
report_drc -file [file join $root build drc.rpt]
puts "BUILD_BITSTREAM=[file join $root build vivado reticula.runs impl_1 top_reticula.bit]"
