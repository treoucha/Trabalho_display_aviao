`timescale 1ns/1ps
module tb_modos;
    logic clk=0, btn=0;
    always #5 clk=~clk;
    tri1 sda,scl;
    wire [3:0] r,g,b;
    wire hs,vs;
    top_reticula dut(clk,2'b0,4'b0,btn,sda,scl,r,g,b,hs,vs);
    defparam dut.u_modo.DEBOUNCE_CYCLES=4;
    integer ocultos=0, criticos=0;
    logic [11:0] esperado;
    initial begin
        wait(dut.pixel_y==480);
        wait(dut.pixel_y==0 && dut.pixel_x==0);
        for(integer quadro=0;quadro<3;quadro++) begin
            for(integer n=0;n<384000;n++) begin
                #1;
                if(dut.declutter !== (quadro==1))
                    $fatal(1,"Quadro=%0d modo obtido=%b esperado=%b",quadro,dut.declutter,quadro==1);
                esperado=0;
                if(dut.video_on) begin
                    if(dut.retic) esperado=12'h0F0;
                    else begin
                        if(dut.alvo || (quadro!=1 && dut.sensor_status && !dut.sensor_ok)) esperado[11:8]=15;
                        if(dut.horizonte || (quadro!=1 && (dut.altitude || dut.velocidade || dut.direcao || dut.numeros || (dut.sensor_status && dut.sensor_ok)))) esperado[7:4]=15;
                    end
                end
                if({r,g,b} !== esperado)
                    $fatal(1,"Quadro=%0d pixel=%0d,%0d RGB obtido=%h esperado=%h",quadro,dut.pixel_x,dut.pixel_y,{r,g,b},esperado);
                if(quadro==1 && (dut.altitude || dut.velocidade || dut.direcao || dut.numeros) && !dut.retic && !dut.alvo && !dut.horizonte) ocultos++;
                if(quadro==1 && (dut.retic || dut.horizonte || dut.alvo)) criticos++;
                // Move o switch durante a imagem; só muda no blanking.
                if(n==80000 && quadro<2) btn=(quadro==0);
                @(posedge dut.pixel_clk);
                // Após o início do blanking já vale a seleção do próximo quadro.
                if(n==383999) begin
                    for(integer k=0;k<36000;k++) begin
                        #1;
                        if({r,g,b} !== 0) $fatal(1,"Blanking RGB obtido=%h esperado=000",{r,g,b});
                        @(posedge dut.pixel_clk);
                    end
                end
            end
        end
        if(ocultos==0 || criticos==0) $fatal(1,"Cobertura: ocultos=%0d críticos=%0d esperados>0",ocultos,criticos);
        $display("PASS modos: NORMAL/DECLUTTER/NORMAL, quadros completos, símbolos críticos e blanking");
        $finish;
    end
endmodule
