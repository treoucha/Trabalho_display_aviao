`timescale 1ns/1ps

module tb_atitude;

logic [9:0] x = 0;
logic [9:0] y = 0;
logic [9:0] centro = 240;
logic ativo = 1;

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

                        if (horizonte)
                            quantidade++;

                    end
                end

                if (quantidade != esperado)
                    $fatal(
                        1,
                        "Deslocamento=%0d: obtido=%0d pixels esperado=%0d",
                        desloc, quantidade, esperado
                    );

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

    $finish;

end

endmodule