`timescale 1ns/1ps
module tb_vga;
    logic clk=0;
    always #5 clk=~clk;
    tri1 sda,scl;
    logic [15:0] sw;
    wire [3:0] r,g,b;
    wire hs,vs;
    top_reticula dut(clk,3'b0,16'h0FFF,sda,scl,r,g,b,hs,vs);
    integer active=0, hlow=0, vlow=0, pixels=0, out_file;
    integer expected_x=0,expected_y=0;
    integer pixels_velocidade=0;
    logic velocidade_esperada;
    time last_pixel;
    initial begin
        // Primeiro ciclo completo prepara a cor pelos switches.
        wait(dut.pixel_y==480); wait(dut.pixel_y==0 && dut.pixel_x==0);
        out_file=$fopen("build/hud.ppm","w");
        $fwrite(out_file,"P3\n640 480\n255\n");
        last_pixel=$time;
        for(int n=0;n<420000;n++) begin
            #1;
            if(dut.pixel_x !== 10'(expected_x) || dut.pixel_y !== 10'(expected_y))
                $fatal(1,"Coordenadas obtidas=%0d,%0d esperadas=%0d,%0d",dut.pixel_x,dut.pixel_y,expected_x,expected_y);
            if(hs !== !(expected_x>=656 && expected_x<752) || vs !== !(expected_y>=490 && expected_y<492))
                $fatal(1,"Sincronismo desalinhado em %0d,%0d",expected_x,expected_y);
            if(dut.video_on !== (expected_x<640 && expected_y<480)) $fatal(1,"Região ativa incorreta");
            velocidade_esperada =
                (expected_x>=79 && expected_x<=81 && expected_y>=100 && expected_y<=380) ||
                (expected_x>=79 && expected_x<=92 && expected_y>=99 && expected_y<=381 &&
                 ((expected_y-99)%40)<3);
            if(dut.velocidade !== velocidade_esperada)
                $fatal(1,"Velocidade em x=%0d y=%0d: obtido=%b esperado=%b",expected_x,expected_y,dut.velocidade,velocidade_esperada);
            if(velocidade_esperada) begin
                pixels_velocidade++;
                if({r,g,b} !== 12'h0F0)
                    $fatal(1,"Escala de velocidade: RGB obtido=%h esperado=0F0",{r,g,b});
            end
            if(!hs) hlow++; if(!vs) vlow++;
            if(dut.video_on) begin
                active++; $fwrite(out_file,"%0d %0d %0d\n",r*17,g*17,b*17);
            end else if({r,g,b} !== 12'h000) $fatal(1,"Blanking: RGB obtido=%h esperado=000",{r,g,b});
            if(dut.retic && {r,g,b} !== 12'h0F0) $fatal(1,"Retículo padrão: obtido=%h esperado=0F0",{r,g,b});
            if(expected_x==315 && expected_y==36 && {r,g,b} !== 12'h0F0)
                $fatal(1,"Letra N: RGB obtido=%h esperado=0F0",{r,g,b});
            if(expected_x==799) begin expected_x=0; expected_y=(expected_y==524)?0:expected_y+1; end
            else expected_x++;
            @(posedge dut.pixel_clk);
            if($time-last_pixel != 40) $fatal(1,"Período de pixel obtido=%0t esperado=40 ns",$time-last_pixel);
            last_pixel=$time;
        end
        $fclose(out_file);
        if(pixels_velocidade!=1113) $fatal(1,"Escala: obtido=%0d pixels esperado=1113",pixels_velocidade);
        $display("PASS velocidade: geometria, oito marcas, verde e limites em quadro completo");
        if(active!=307200 || hlow!=50400 || vlow!=1600) $fatal(1,"Contagem de quadro incorreta");
        $display("PASS VGA: 420000 pixels, 307200 ativos, HS=96 pixels/linha, VS=2 linhas, pixel=40 ns");
        $finish;
    end
endmodule
