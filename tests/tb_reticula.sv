`timescale 1ns/1ps
module tb_reticula;
    logic [9:0] x, y;
    logic video_on = 1;
    wire [2:0] mask;
    wire sem_vao;
    for (genvar i=0; i<3; i++) begin : g
        reticula_vga #(.ESPESSURA(i+1)) dut(x,y,video_on,mask[i]);
    end
    reticula_vga #(.VAO_CENTRAL(0)) continua(x,y,video_on,sem_vao);
    integer count[3];
    initial begin
        for (int i=0;i<3;i++) count[i]=0;
        for (int py=0;py<525;py++) begin
            for (int px=0;px<800;px++) begin
                x=10'(px); y=10'(py); video_on=(px<640 && py<480); #1;
                for (int i=0;i<3;i++) begin
                    if (mask[i]) count[i]++;
                    if ((!video_on || (px>=314 && px<=326 && py>=234 && py<=246)) && mask[i])
                        $fatal(1,"Entrada x=%0d y=%0d: obtido pixel aceso, esperado apagado",px,py);
                end
            end
        end
        // Quatro braços com 34 pixels de comprimento e espessuras 1, 2, 3.
        for(int i=0;i<3;i++)
            if(count[i] != 136*(i+1)) $fatal(1,"Espessura=%0d: obtido %0d pixels, esperado %0d",i+1,count[i],136*(i+1));
        x=320; y=240; video_on=1; #1;
        if(sem_vao !== 1) $fatal(1,"Vão=0: centro obtido apagado, esperado aceso");
        x=330; y=238; #1; if(mask !== 0) $fatal(1,"y=238: esperado fora das três linhas");
        y=239; #1; if(mask !== 3'b110) $fatal(1,"y=239: obtido %b esperado 110",mask);
        y=240; #1; if(mask !== 3'b111) $fatal(1,"y=240: obtido %b esperado 111",mask);
        y=241; #1; if(mask !== 3'b100) $fatal(1,"y=241: obtido %b esperado 100",mask);
        video_on=0; #1; if(mask !== 0 || sem_vao !== 0) $fatal(1,"Blanking: esperado preto");
        $display("PASS retículo: espessuras 1/2/3, vão 0/6 e blanking"); $finish;
    end
endmodule
