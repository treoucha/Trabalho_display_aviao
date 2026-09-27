`timescale 1ns/1ps
module tb_horizonte;
    logic clk=0;
    logic [9:0] amostra_y;
    always #5 clk=~clk;
    logic [15:0] sw;
    tri1 sda,scl;
    wire [3:0] r,g,b;
    wire hs,vs;
    top_reticula dut(clk,3'b0,sw,sda,scl,r,g,b,hs,vs);
    task ciclos;
        repeat(16) @(negedge dut.pixel_clk);
    endtask
    task testar(input logic [1:0] posicao, input int esperado);
        logic [9:0] anterior;
        anterior=dut.horizonte_y;
        force dut.u_vga.h_cont=100; force dut.u_vga.v_cont=100;
        sw[13:12]=posicao; ciclos();
        if(dut.horizonte_y !== anterior) $fatal(1,"Posição mudou durante região ativa");
        force dut.u_vga.h_cont=0; force dut.u_vga.v_cont=480; ciclos();
        if(dut.horizonte_y !== 10'(esperado))
            $fatal(1,"SW13..12=%b: obtido y=%0d esperado=%0d",posicao,dut.horizonte_y,esperado);
        // Amostra os limites da linha e os dois lados do vão.
        force dut.u_vga.h_cont=100;
        amostra_y=dut.horizonte_y-10'd2; force dut.u_vga.v_cont=amostra_y; #1;
        if(dut.horizonte !== 0) $fatal(1,"Borda superior externa: esperado apagado");
        amostra_y=dut.horizonte_y-10'd1; force dut.u_vga.v_cont=amostra_y; #1;
        if(dut.horizonte !== 1) $fatal(1,"Borda superior: esperado aceso");
        amostra_y=dut.horizonte_y+10'd1; force dut.u_vga.v_cont=amostra_y; #1;
        if(dut.horizonte !== 1) $fatal(1,"Borda inferior: esperado aceso");
        amostra_y=dut.horizonte_y+10'd2; force dut.u_vga.v_cont=amostra_y; #1;
        if(dut.horizonte !== 0) $fatal(1,"Borda inferior externa: esperado apagado");
        force dut.u_vga.v_cont=dut.horizonte_y;
        force dut.u_vga.h_cont=300; #1; if(!dut.horizonte) $fatal(1,"Fim braço esquerdo");
        force dut.u_vga.h_cont=320; #1; if(dut.horizonte) $fatal(1,"Vão do horizonte");
        force dut.u_vga.h_cont=340; #1; if(!dut.horizonte) $fatal(1,"Início braço direito");
        force dut.u_vga.h_cont=541; #1; if(dut.horizonte) $fatal(1,"Limite direito");
        force dut.u_vga.h_cont=320; force dut.u_vga.v_cont=210; #1;
        if(dut.retic !== 1) $fatal(1,"Retículo deve permanecer fixo");
        force dut.u_vga.h_cont=640; #1;
        if(dut.horizonte !== 0) $fatal(1,"Blanking: esperado apagado");
    endtask
    initial begin
        testar(2'b00,240); testar(2'b01,200);
        testar(2'b10,280); testar(2'b11,240);
        release dut.u_vga.h_cont; release dut.u_vga.v_cont;
        $display("PASS horizonte: quatro combinações, atualização entre quadros, bordas, vão e retículo fixo");
        $finish;
    end
endmodule
