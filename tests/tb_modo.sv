`timescale 1ns/1ps
module tb_modo;
    logic clk=0, sw=0, atualizar=0;
    wire modo;
    always #5 clk=~clk;
    controle_modo #(.DEBOUNCE_CYCLES(4)) dut(clk,sw,atualizar,modo);
    task automatic ciclos(input integer n);
        repeat(n) @(negedge clk);
    endtask
    task automatic aplicar(input logic esperado);
        atualizar=1; ciclos(1); atualizar=0;
        if(modo !== esperado) $fatal(1,"SW=%b modo obtido=%b esperado=%b",sw,modo,esperado);
    endtask
    initial begin
        ciclos(2); aplicar(0);
        sw=1; ciclos(1); sw=0; ciclos(8); aplicar(0);
        sw=1; ciclos(10);
        if(modo !== 0) $fatal(1,"Durante quadro: obtido=%b esperado=0",modo);
        aplicar(1); ciclos(20); aplicar(1);
        sw=0; ciclos(10);
        if(modo !== 1) $fatal(1,"Durante quadro: obtido=%b esperado=1",modo);
        aplicar(0);
        $display("PASS modo: repique ignorado, SW0=0 NORMAL, SW0=1 DECLUTTER, aplicação entre quadros");
        $finish;
    end
endmodule
