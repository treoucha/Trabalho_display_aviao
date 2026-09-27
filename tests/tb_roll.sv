`timescale 1ns/1ps
module tb_roll;
    logic [9:0] x=192,y=208;
    logic signed [9:0] roll=64;
    logic ativo=1;
    wire h,a,d,t,v;
    simbologia_vga dut(x,y,ativo,10'd240,roll,h,a,d,t,v);
    initial begin
        #1; if(!h) $fatal(1,"Roll positivo: esquerda deveria subir");
        x=448; y=272; #1; if(!h) $fatal(1,"Roll positivo: direita deveria descer");
        y=240; #1; if(h) $fatal(1,"Horizonte permaneceu horizontal");
        roll=-64; y=208; #1; if(!h) $fatal(1,"Roll negativo: direita deveria subir");
        x=192; y=272; #1; if(!h) $fatal(1,"Roll negativo: esquerda deveria descer");
        x=80; y=200; #1; if(!v) $fatal(1,"Escala de velocidade deslocada pelo roll");
        ativo=0; #1; if(h||a||d||t||v) $fatal(1,"Blanking com roll");
        $display("PASS roll: inclinação nos dois sentidos e escala fixa"); $finish;
    end
endmodule
