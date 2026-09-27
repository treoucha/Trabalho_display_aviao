`timescale 1ns/1ps
module tb_atitude;
    logic [9:0] x=0,y=0,centro=240;
    logic ativo=1;
    wire horizonte,altitude,direcao,alvo,velocidade;
    simbologia_vga dut(x,y,ativo,centro,10'sd0,horizonte,altitude,direcao,alvo,velocidade);
    integer linha,quantidade;
    task pixel(input int px,input int py,input logic esperado);
        x=10'(px); y=10'(py); #1;
        if(horizonte !== esperado)
            $fatal(1,"Centro=%0d x=%0d y=%0d: obtido=%b esperado=%b",centro,px,py,horizonte,esperado);
    endtask
    initial begin
        for(int c=200;c<=280;c+=40) begin
            centro=10'(c);
            for(int desloc=-80;desloc<=80;desloc+=40) begin
                if(desloc!=0) begin
                    linha=c+desloc; quantidade=0;
                    for(int py=linha-1;py<=linha+2;py++) begin
                        for(int px=0;px<640;px++) begin
                            x=10'(px); y=10'(py); #1;
                            if(horizonte) begin
                                quantidade++;
                                if(py<linha || py>linha+1 || px<260 || px>379 || (px>=300 && px<=339))
                                    $fatal(1,"Marca fora dos limites em %0d,%0d",px,py);
                            end
                        end
                    end
                    if(quantidade != (desloc<0 ? 160 : 96))
                        $fatal(1,"Deslocamento=%0d: obtido=%0d pixels esperado=%0d",desloc,quantidade,desloc<0?160:96);
                    pixel(260,linha,1); pixel(299,linha,1);
                    pixel(340,linha,1); pixel(379,linha,1);
                    pixel(270,linha,desloc<0); pixel(350,linha,desloc<0);
                    pixel(320,linha,0);
                    ativo=0; pixel(260,linha,0); ativo=1;
                end
            end
            pixel(100,c,1); pixel(320,c,0); pixel(540,c,1);
        end
        $display("PASS atitude: três posições, quatro marcas, traços, espessura, vão e blanking");
        $finish;
    end
endmodule
