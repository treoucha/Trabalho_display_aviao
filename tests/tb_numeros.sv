`timescale 1ns/1ps
module tb_numeros;
    logic [9:0] x=0,y=0,vel=280;
    logic [16:0] alt=36000;
    logic ativo=1;
    wire on;
    numeros_hud dut(x,y,ativo,vel,alt,on);
    logic [14:0] referencia[0:9];
    integer count;
    task digito(input int inicio_x,input int numero);
        for(int py=0;py<10;py++) begin
            for(int px=0;px<8;px++) begin
                x=10'(inicio_x+px); y=10'(402+py); #1;
                if(on !== ((px<6) ? referencia[numero][14-(py/2)*3-px/2] : 1'b0))
                    $fatal(1,"Dígito=%0d x=%0d y=%0d pixel incorreto",numero,x,y);
            end
        end
    endtask
    initial begin
        referencia[0]=15'b111101101101111; referencia[1]=15'b010110010010111;
        referencia[2]=15'b111001111100111; referencia[3]=15'b111001111001111;
        referencia[4]=15'b101101111001001; referencia[5]=15'b111100111001111;
        referencia[6]=15'b111100111101111; referencia[7]=15'b111001010010010;
        referencia[8]=15'b111101111101111; referencia[9]=15'b111101111001111;
        for(int n=0;n<10;n++) begin vel=10'(n); digito(62,n); end
        vel=123; alt=45678;
        digito(46,1); digito(54,2); digito(62,3);
        digito(572,4); digito(580,5); digito(588,6); digito(596,7); digito(604,8);
        vel=0; alt=0; x=46; y=402; #1; if(on) $fatal(1,"Zero à esquerda deve ficar vazio");
        // Primeira marca acima de zero é 70; marca abaixo do limite fica vazia.
        for(int px=46;px<70;px++) begin
            for(int py=255;py<265;py++) begin x=10'(px); y=10'(py); #1; if(on) $fatal(1,"Valor negativo deu volta"); end
        end
        vel=999; alt=99999;
        for(int px=572;px<612;px++) begin
            for(int py=95;py<105;py++) begin x=10'(px); y=10'(py); #1; if(on) $fatal(1,"Overflow da altitude visível"); end
        end
        ativo=0; x=62; y=402; #1; if(on) $fatal(1,"Blanking dos números");
        $display("PASS números: dez dígitos, composição decimal, ampliação, zeros e limites"); $finish;
    end
endmodule
