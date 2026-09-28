# Estimativa por domínio a partir do pior caminho de setup de um ciclo.
set f [open [file join $root build fmax.rpt] w]
puts $f "Fmax estimada por domínio; não é uma busca de frequência com nova implementação."
puts $f "Caminhos entre domínios e I/O devem ser avaliados no timing_summary.rpt."
foreach clock [get_clocks] {
    set nome [get_property NAME $clock]
    set periodo [get_property PERIOD $clock]
    set paths [get_timing_paths -from $clock -to $clock -delay_type max -max_paths 1]
    if {[llength $paths] == 0} {
        puts $f "$nome: sem caminho interno de setup disponível"
        continue
    }
    set path [lindex $paths 0]
    set slack [get_property SLACK $path]
    set requisito [get_property REQUIREMENT $path]
    if {abs($requisito - $periodo) > 0.001 || ($periodo - $slack) <= 0} {
        puts $f "$nome: estimativa simples não aplicável (requisito=$requisito ns, período=$periodo ns)"
        continue
    }
    set fmax [expr {1000.0 / ($periodo - $slack)}]
    puts $f [format "%s: período=%.3f ns, frequência=%.3f MHz, slack=%.3f ns, Fmax estimada=%.3f MHz" $nome $periodo [expr {1000.0/$periodo}] $slack $fmax]
    puts $f "  Início: [get_property STARTPOINT_PIN $path]"
    puts $f "  Fim: [get_property ENDPOINT_PIN $path]"
}
close $f
