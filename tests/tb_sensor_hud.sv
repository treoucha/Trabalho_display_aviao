`timescale 1ns/1ps
module tb_sensor_hud;
    logic clk=0;
    always #5 clk=~clk;
    tri1 sda,scl;
    wire [3:0] r,g,b;
    wire hs,vs;
    logic [1:0] buttons=0;
    top_reticula dut(clk,buttons,4'b0,1'b0,sda,scl,r,g,b,hs,vs);
    defparam dut.u_atitude.CAL_LOG2=2;
    defparam dut.u_heading.DEBOUNCE_CYCLES=2;
    logic valid=0,ok=1;
    logic signed [15:0] x=0,y=0,z=16384;
    task sample(input integer sx,sy);
        @(negedge clk);x=16'(sx);y=16'(sy);valid=1;
        @(negedge clk);valid=0;
        repeat(80) @(negedge clk);
    endtask
    initial begin
        force dut.sensor_ok=ok; force dut.sensor_amostra=valid;
        force dut.ax=x;force dut.ay=y;force dut.az=z;
        force dut.gx=0;force dut.gy=0;force dut.gz=0;
        force dut.u_vga.h_cont=100;force dut.u_vga.v_cont=100;
        repeat(4) sample(0,0);
        repeat(32) sample(4096,4096);
        if(dut.horizonte_y != 240 || dut.roll_q8 != 0)
            $fatal(1,"Regiao ativa: horizonte mudou antes do quadro");
        force dut.u_vga.h_cont=0;force dut.u_vga.v_cont=480;
        repeat(30) @(negedge clk);
        if(dut.horizonte_y < 279 || dut.horizonte_y > 280 || dut.roll_q8 < 63 || dut.roll_q8 > 64 || !dut.sensor_pronto)
            $fatal(1,"Quadro: obtido y=%0d roll=%0d pronto=%b esperado=280,64,1",dut.horizonte_y,dut.roll_q8,dut.sensor_pronto);
        if(dut.velocidade_kt != 280 || dut.altitude_ft != 36000) $fatal(1,"Valores simulados alterados");
        force dut.u_vga.h_cont=100;force dut.u_vga.v_cont=100;
        ok=0;buttons=1;repeat(100) @(negedge clk);
        if(!dut.sensor_pronto) $fatal(1,"Status mudou no meio do quadro");
        force dut.u_vga.h_cont=0;force dut.u_vga.v_cont=480;
        repeat(30) @(negedge clk);
        if(dut.heading_deg != 10) $fatal(1,"Sensor ausente: heading obtido=%0d esperado=10",dut.heading_deg);
        if(dut.sensor_pronto || dut.horizonte_y < 279 || dut.roll_q8 < 63)
            $fatal(1,"Desconexao: esperado status invalido e ultima atitude retida");
        force dut.u_vga.h_cont=320;force dut.u_vga.v_cont=210;#1;
        if(!dut.retic) $fatal(1,"Reticulo central apagado");
        force dut.u_vga.h_cont=319;#1;
        if(dut.retic) $fatal(1,"Reticulo: espessura obtida>1 esperada=1");
        $display("PASS sensor HUD: atitude pela ponte, quadro atomico, status, desconexao e reticulo de 1 pixel");
        $finish;
    end
    initial begin #1000000;$fatal(1,"Timeout integracao");end
endmodule
