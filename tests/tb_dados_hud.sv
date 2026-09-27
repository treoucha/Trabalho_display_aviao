`timescale 1ns/1ps
module tb_dados_hud;
    logic clk=0;
    always #20 clk=~clk;
    logic quadro=0,valido=0;
    logic [9:0] vel=0;
    logic [16:0] alt=0;
    logic signed [10:0] pitch=0;
    logic signed [9:0] roll=0;
    logic [8:0] heading=0;
    wire [9:0] v,y;
    wire [16:0] a;
    wire signed [9:0] r;
    wire [8:0] h;
    dados_hud dut (
        .clk(clk),
        .atualizar_quadro(quadro),
        .dados_validos(valido),

        .velocidade_kt_in(vel),
        .altitude_ft_in(alt),
        .pitch_px_in(pitch),
        .roll_q8_in(roll),
        .heading_deg_in(heading),

        .velocidade_kt(v),
        .altitude_ft(a),
        .horizonte_y(y),
        .roll_q8(r),
        .heading_deg(h)
    );
    task ciclo; @(posedge clk); #1; @(negedge clk); endtask
    initial begin
        ciclo();
        vel=321; alt=45678; pitch=-40; roll=64; heading=275; valido=1; ciclo(); valido=0;
        if(v!=280 || a!=36000 || y!=240 || r!=0 || h!=0) $fatal(1,"Dados mudaram durante o quadro");
        vel=0; alt=0; pitch=0; roll=0; repeat(3) ciclo();
        quadro=1; ciclo(); quadro=0;
        if(v!=321 || a!=45678 || y!=200 || r!=64 || h!=275) $fatal(1,"Amostra entre quadros foi perdida");
        vel=1023; alt=131071; pitch=1023; roll=511; valido=1; ciclo(); valido=0;
        quadro=1; ciclo(); quadro=0;
        if(v!=999 || a!=99999 || y!=320 || r!=128) $fatal(1,"Limites superiores incorretos");
        pitch=-1024; roll=-512; valido=1; quadro=1; ciclo();
        if(y!=320) $fatal(1,"Amostra simultânea deve aguardar próximo quadro");
        valido=0; quadro=0; ciclo(); quadro=1; ciclo(); quadro=0;
        if(y!=160 || r!=-128) $fatal(1,"Limites inferiores incorretos");
        $display("PASS dados: captura atômica, pulso válido, retenção, coincidência e saturação"); $finish;
        if(v!=999 || a!=99999 || y!=320 || r!=128 || h!=359)
        $fatal(1,"Limites superiores incorretos");
    end
endmodule
