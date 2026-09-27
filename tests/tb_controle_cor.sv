`timescale 1ns/1ps
module tb_controle_cor;
    logic clk=0;
    always #20 clk=~clk;
    logic [2:0] btn=0;
    logic [11:0] sw=12'hABC;
    logic atualizar=0;
    wire [11:0] rgb;
    controle_cor #(.DEBOUNCE_CYCLES(4)) dut(clk,btn,sw,atualizar,rgb);
    task ciclos(input int n); repeat(n) @(negedge clk); endtask
    task conferir(input logic [11:0] esperado);
        atualizar=1; ciclos(1); atualizar=0;
        if(rgb !== esperado) $fatal(1,"Botões=%b SW=%h: obtido=%h esperado=%h",btn,sw,rgb,esperado);
    endtask
    initial begin
        ciclos(8); conferir(12'h0B0);
        btn=1; ciclos(1); btn=0; ciclos(8); conferir(12'h0B0); // Repique rejeitado.
        btn=1; ciclos(8); conferir(12'h0BC);
        ciclos(20); conferir(12'h0BC); // Manter pressionado não repete.
        btn=0; ciclos(8); conferir(12'h0BC);
        btn=1; ciclos(8); conferir(12'h0B0); // Segunda pressão desliga R.
        btn=0; ciclos(8); btn=3'b101; ciclos(8); conferir(12'hABC);
        btn=0; ciclos(8);
        for(int valor=0;valor<16;valor++) begin
            sw={4'(valor),4'(valor),4'(valor)};
            ciclos(4);
            if(rgb !== (valor==0 ? 12'hABC : {4'(valor-1),4'(valor-1),4'(valor-1)}))
                $fatal(1,"Cor mudou sem atualizar");
            conferir(sw);
        end
        btn=3'b111; ciclos(8); conferir(0);
        $display("PASS controles: repique, pressão longa, soltura, simultâneos, 16 intensidades e atualização"); $finish;
    end
endmodule
