`timescale 1ns/1ps

module tb_atitude;

logic [9:0] x = 0;
logic [9:0] y = 0;
logic [9:0] centro = 240;
logic ativo = 1;
logic [8:0] heading = 0;

wire horizonte;
wire altitude;
wire direcao;
wire alvo;
wire velocidade;

simbologia_vga dut (
    x,
    y,
    ativo,
    centro,
    10'sd0,
    heading,
    horizonte,
    altitude,
    direcao,
    alvo,
    velocidade
);

integer linha;
integer quantidade;
integer esperado;

task pixel(
    input int px,
    input int py,
    input logic valor_esperado
);
begin
    x = 10'(px);
    y = 10'(py);
    #1;

    if (horizonte !== valor_esperado)
        $fatal(
            1,
            "Centro=%0d x=%0d y=%0d: obtido=%b esperado=%b",
            centro, px, py, horizonte, valor_esperado
        );
end
endtask

task cardinal(input int rumo, input int centro_x, input logic [24:0] glifo);
    logic aceso;
    heading = 9'(rumo);
    for (int py = 35; py <= 46; py++) begin
        for (int px = 0; px < 640; px++) begin
            aceso = 0;
            if (px >= 160 && px <= 480 && py >= 36 && py < 46 &&
                px >= centro_x-5 && px < centro_x+5)
                aceso = glifo[24-((py-36)/2)*5-(px-centro_x+5)/2];
            x = 10'(px); y = 10'(py); #1;
            if (direcao !== aceso)
                $fatal(1,"Rumo=%0d x=%0d y=%0d: obtido=%b esperado=%b",rumo,px,py,direcao,aceso);
        end
    end
endtask

task pixel_direcao(input int px, input int py, input logic esperado);
    x = 10'(px); y = 10'(py); #1;
    if (direcao !== esperado)
        $fatal(1,"Rumo=%0d x=%0d y=%0d: obtido=%b esperado=%b",heading,px,py,direcao,esperado);
endtask

initial begin

    // Testa três posições verticais do horizonte.
    for (int c = 200; c <= 280; c += 40) begin

        centro = 10'(c);

        // ±10°, ±20°, ±30° e ±40°
        for (int desloc = -160; desloc <= 160; desloc += 40) begin

            if (desloc != 0) begin

                linha = c + desloc;
                quantidade = 0;

                // Quantidade esperada de pixels para cada tipo de marca.
                case (desloc)

                    // +10° / +20°: linhas contínuas longas
                    -40, -80:
                        esperado = 204;

                    // +30°: linha contínua média
                    -120:
                        esperado = 144;

                    // +40°: linha contínua curta
                    -160:
                        esperado = 92;

                    // -10° / -20°: tracejado longo
                    40, 80:
                        esperado = 132;

                    // -30°: tracejado médio
                    120:
                        esperado = 72;

                    // -40°: tracejado curto
                    160:
                        esperado = 56;

                    default:
                        esperado = 0;

                endcase

                // Conta pixels produzidos pela marca.
                for (int py = linha - 1; py <= linha + 2; py++) begin
                    for (int px = 0; px < 640; px++) begin

                        x = 10'(px);
                        y = 10'(py);
                        #1;

                    if (
                        horizonte &&
                        (px >= 250) &&
                        (px <= 390)
                    )
                        quantidade++;

                    end
                end
                

                if (quantidade != esperado)
                    $fatal(
                        1,
                        "Deslocamento=%0d: obtido=%0d pixels esperado=%0d",
                        desloc, quantidade, esperado
                    );
                // O zero do número de pitch deve existir nos dois lados.
                pixel(234, linha - 5, 1);
                pixel(406, linha - 5, 1);

                // Região central deve permanecer vazia.
                pixel(320, linha, 0);

                // Blanking.
                ativo = 0;
                pixel(280, linha, 0);
                ativo = 1;

            end
        end

        // Horizonte principal, separado pelo retículo central.
        pixel(100, c, 1);
        pixel(320, c, 0);
        pixel(540, c, 1);

    end

    $display(
        "PASS atitude: tres posicoes, marcas de pitch +/-10/20/30/40, espessura, vao e blanking"
    );

    cardinal(0,   320, 25'b10001_11001_10101_10011_10001);
    cardinal(90,  320, 25'b11111_10000_11110_10000_11111);
    cardinal(180, 320, 25'b11111_10000_11111_00001_11111);
    cardinal(270, 320, 25'b10001_10001_10101_11111_10001);
    cardinal(359, 324, 25'b10001_11001_10101_10011_10001);
    cardinal(1,   316, 25'b10001_11001_10101_10011_10001);
    cardinal(40,  160, 25'b10001_11001_10101_10011_10001);
    cardinal(320, 480, 25'b10001_11001_10101_10011_10001);
    cardinal(45,  140, 25'b10001_11001_10101_10011_10001);

    heading = 359;
    pixel_direcao(324,48,1); // Norte: marca maior, quatro pixels à direita.
    pixel_direcao(284,53,1); // 350 graus: marca menor.
    pixel_direcao(284,48,0);
    pixel_direcao(320,48,0);
    pixel_direcao(320,66,1); // Indicador central permanece fixo.
    heading = 0;
    pixel_direcao(320,48,1);
    pixel_direcao(159,60,0);
    pixel_direcao(481,60,0);
    ativo = 0;
    pixel_direcao(315,36,0);
    pixel_direcao(320,48,0);
    pixel_direcao(320,66,0);
    $display("PASS direção: N/E/S/W, escala 2x, limites da fita, wrap e blanking");
    $finish;

end

endmodule
