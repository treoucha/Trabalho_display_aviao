// =========================================================
// simbologia_vga.sv
// Simbologia básica do display de avião.
// Geração procedural por coordenadas.
// =========================================================

module simbologia_vga (
    input  logic [9:0] pixel_x,
    input  logic [9:0] pixel_y,
    input  logic       video_on,
    input  logic [9:0] horizonte_y, // Centro limitado a 160..320.
    input  logic signed [9:0] roll_q8, // Inclinação: pixels por 256 pixels em X.

    output logic       horizonte_on,
    output logic       altitude_on,
    output logic       direcao_on,
    output logic       alvo_on,
    output logic       velocidade_on
);

    logic horizonte_esq;
    logic horizonte_dir;
    logic marcas_superiores;
    logic marcas_inferiores;

    logic faixa_longa;
    logic faixa_media;
    logic faixa_curta;

    logic tracos_longo;
    logic tracos_medio;
    logic tracos_curto;
    logic signed [21:0] distancia_horizonte;
    logic signed [21:0] deslocamento_roll;
    // Números da escada de pitch.
    logic pitch_numeros;
    logic pitch_campo;
    logic [14:0] pitch_bitmap;

    integer pitch_coluna;
    integer pitch_linha;
    integer pitch_nivel;
    integer pitch_codigo;

    logic altitude_barra;
    logic altitude_marcas;
    logic graduacao_y;
    logic velocidade_barra;
    logic velocidade_marcas;

    logic direcao_barra;
    logic direcao_marcas;
    logic direcao_centro;

    logic alvo_sup_esq;
    logic alvo_sup_dir;
    logic alvo_inf_esq;
    logic alvo_inf_dir;

    localparam int ALVO_X = 430;
    localparam int ALVO_Y = 180;
    localparam int ALVO_M = 24;
    localparam int CANTO  = 10;

    function automatic logic [14:0] glifo_pitch(input integer codigo);
        case (codigo)
            0: glifo_pitch = 15'b111_101_101_101_111;
            1: glifo_pitch = 15'b010_110_010_010_111;
            2: glifo_pitch = 15'b111_001_111_100_111;
            3: glifo_pitch = 15'b111_001_111_001_111;
            4: glifo_pitch = 15'b101_101_111_001_001;
            default: glifo_pitch = '0;
        endcase
    endfunction

    always_comb begin
            pitch_numeros = 1'b0;
            pitch_campo   = 1'b0;
            pitch_bitmap  = '0;

            pitch_coluna = 0;
            pitch_linha  = 0;
            pitch_nivel  = 0;
            pitch_codigo = 0;
        distancia_horizonte =
            $signed({12'b0, pixel_y}) -
            $signed({12'b0, horizonte_y}) -
            deslocamento_roll;
        // -------------------------------------------------
        // Horizonte artificial
        // -------------------------------------------------

        // Inclinação linear da simbologia; escalas e retículo permanecem fixos.
        deslocamento_roll = (($signed({12'b0, pixel_x}) - 22'sd320) * 22'(roll_q8)) >>> 8;
        distancia_horizonte = $signed({12'b0, pixel_y}) - $signed({12'b0, horizonte_y}) - deslocamento_roll;

            // -------------------------------------------------
            // Números da escada de pitch
            // 10 / 20 / 30 / 40 nos dois lados.
            // A posição vertical usa a mesma transformação do
            // horizonte, portanto acompanha pitch e roll.
            // -------------------------------------------------

        if (
            ((pixel_x >= 226) && (pixel_x < 242)) ||
            ((pixel_x >= 398) && (pixel_x < 414))
        ) begin

            if ((pixel_x >= 226) && (pixel_x < 242))
                pitch_coluna = int'(pixel_x) - 226;
            else
                pitch_coluna = int'(pixel_x) - 398;

            // +10°
            if (
                (distancia_horizonte >= -22'sd45) &&
                (distancia_horizonte <= -22'sd36)
            ) begin
                pitch_campo = 1'b1;
                pitch_nivel = 1;
                pitch_linha = int'(distancia_horizonte + 22'sd45) / 2;
            end

            // +20°
            else if (
                (distancia_horizonte >= -22'sd85) &&
                (distancia_horizonte <= -22'sd76)
            ) begin
                pitch_campo = 1'b1;
                pitch_nivel = 2;
                pitch_linha = int'(distancia_horizonte + 22'sd85) / 2;
            end

            // +30°
            else if (
                (distancia_horizonte >= -22'sd125) &&
                (distancia_horizonte <= -22'sd116)
            ) begin
                pitch_campo = 1'b1;
                pitch_nivel = 3;
                pitch_linha = int'(distancia_horizonte + 22'sd125) / 2;
            end

            // +40°
            else if (
                (distancia_horizonte >= -22'sd165) &&
                (distancia_horizonte <= -22'sd156)
            ) begin
                pitch_campo = 1'b1;
                pitch_nivel = 4;
                pitch_linha = int'(distancia_horizonte + 22'sd165) / 2;
            end

            // -10°
            else if (
                (distancia_horizonte >= 22'sd35) &&
                (distancia_horizonte <= 22'sd44)
            ) begin
                pitch_campo = 1'b1;
                pitch_nivel = 1;
                pitch_linha = int'(distancia_horizonte - 22'sd35) / 2;
            end

            // -20°
            else if (
                (distancia_horizonte >= 22'sd75) &&
                (distancia_horizonte <= 22'sd84)
            ) begin
                pitch_campo = 1'b1;
                pitch_nivel = 2;
                pitch_linha = int'(distancia_horizonte - 22'sd75) / 2;
            end

            // -30°
            else if (
                (distancia_horizonte >= 22'sd115) &&
                (distancia_horizonte <= 22'sd124)
            ) begin
                pitch_campo = 1'b1;
                pitch_nivel = 3;
                pitch_linha = int'(distancia_horizonte - 22'sd115) / 2;
            end

            // -40°
            else if (
                (distancia_horizonte >= 22'sd155) &&
                (distancia_horizonte <= 22'sd164)
            ) begin
                pitch_campo = 1'b1;
                pitch_nivel = 4;
                pitch_linha = int'(distancia_horizonte - 22'sd155) / 2;
            end

            if (pitch_campo) begin

                // Primeiro dígito: 1/2/3/4
                // Segundo dígito: 0
                if (pitch_coluna < 8)
                    pitch_codigo = pitch_nivel;
                else
                    pitch_codigo = 0;

                pitch_bitmap = glifo_pitch(pitch_codigo);

                if ((pitch_coluna % 8) < 6)
                    pitch_numeros =
                        pitch_bitmap[
                            14 -
                            (
                                pitch_linha * 3 +
                                ((pitch_coluna % 8) / 2)
                            )
                        ];
            end
        end

        horizonte_esq =
            (distancia_horizonte >= -22'sd1) &&
            (distancia_horizonte <= 22'sd1) &&
            (pixel_x >= 100) &&
            (pixel_x <= 300);

        horizonte_dir =
            (distancia_horizonte >= -22'sd1) &&
            (distancia_horizonte <= 22'sd1) &&
            (pixel_x >= 340) &&
            (pixel_x <= 540);

        // -------------------------------------------------
// Escada de pitch
//
// Convenção visual temporária:
// 40 pixels = 10 graus.
//
// Acima do horizonte: linhas contínuas.
// Abaixo do horizonte: linhas tracejadas.
// -------------------------------------------------

// ±10° e ±20°
faixa_longa =
    ((pixel_x >= 250) && (pixel_x <= 300)) ||
    ((pixel_x >= 340) && (pixel_x <= 390));

// ±30°
faixa_media =
    ((pixel_x >= 265) && (pixel_x <= 300)) ||
    ((pixel_x >= 340) && (pixel_x <= 375));

// ±40°
faixa_curta =
    ((pixel_x >= 278) && (pixel_x <= 300)) ||
    ((pixel_x >= 340) && (pixel_x <= 362));


// Tracejado longo
tracos_longo =
    ((pixel_x >= 250) && (pixel_x <= 260)) ||
    ((pixel_x >= 270) && (pixel_x <= 280)) ||
    ((pixel_x >= 290) && (pixel_x <= 300)) ||

    ((pixel_x >= 340) && (pixel_x <= 350)) ||
    ((pixel_x >= 360) && (pixel_x <= 370)) ||
    ((pixel_x >= 380) && (pixel_x <= 390));

// Tracejado médio
tracos_medio =
    ((pixel_x >= 265) && (pixel_x <= 273)) ||
    ((pixel_x >= 283) && (pixel_x <= 291)) ||
    ((pixel_x >= 340) && (pixel_x <= 348)) ||
    ((pixel_x >= 358) && (pixel_x <= 366));

// Tracejado curto
tracos_curto =
    ((pixel_x >= 278) && (pixel_x <= 284)) ||
    ((pixel_x >= 294) && (pixel_x <= 300)) ||
    ((pixel_x >= 340) && (pixel_x <= 346)) ||
    ((pixel_x >= 356) && (pixel_x <= 362));


// Pitch positivo
marcas_superiores =

    // +10°
    (faixa_longa &&
        (distancia_horizonte >= -22'sd40) &&
        (distancia_horizonte <= -22'sd39))

    ||

    // +20°
    (faixa_longa &&
        (distancia_horizonte >= -22'sd80) &&
        (distancia_horizonte <= -22'sd79))

    ||

    // +30°
    (faixa_media &&
        (distancia_horizonte >= -22'sd120) &&
        (distancia_horizonte <= -22'sd119))

    ||

    // +40°
    (faixa_curta &&
        (distancia_horizonte >= -22'sd160) &&
        (distancia_horizonte <= -22'sd159));


// Pitch negativo
marcas_inferiores =

    // -10°
    (tracos_longo &&
        (distancia_horizonte >= 22'sd40) &&
        (distancia_horizonte <= 22'sd41))

    ||

    // -20°
    (tracos_longo &&
        (distancia_horizonte >= 22'sd80) &&
        (distancia_horizonte <= 22'sd81))

    ||

    // -30°
    (tracos_medio &&
        (distancia_horizonte >= 22'sd120) &&
        (distancia_horizonte <= 22'sd121))

    ||

    // -40°
    (tracos_curto &&
        (distancia_horizonte >= 22'sd160) &&
        (distancia_horizonte <= 22'sd161));

        horizonte_on =
            video_on &&
            (horizonte_esq || horizonte_dir ||
            marcas_superiores || marcas_inferiores || pitch_numeros);

        // -------------------------------------------------
        // Escala de altitude
        // -------------------------------------------------

        altitude_barra =
            (pixel_x >= 559) &&
            (pixel_x <= 561) &&
            (pixel_y >= 100) &&
            (pixel_y <= 380);

        graduacao_y =
            (
                ((pixel_y >=  99) && (pixel_y <= 101)) ||
                ((pixel_y >= 139) && (pixel_y <= 141)) ||
                ((pixel_y >= 179) && (pixel_y <= 181)) ||
                ((pixel_y >= 219) && (pixel_y <= 221)) ||
                ((pixel_y >= 259) && (pixel_y <= 261)) ||
                ((pixel_y >= 299) && (pixel_y <= 301)) ||
                ((pixel_y >= 339) && (pixel_y <= 341)) ||
                ((pixel_y >= 379) && (pixel_y <= 381))
            );

        altitude_marcas =
            (pixel_x >= 548) && (pixel_x <= 561) && graduacao_y;

        altitude_on =
            video_on &&
            (altitude_barra || altitude_marcas);

        // Escala de velocidade: espelho da altitude, com marcas para dentro.
        velocidade_barra =
            (pixel_x >= 79) && (pixel_x <= 81) &&
            (pixel_y >= 100) && (pixel_y <= 380);
        velocidade_marcas =
            (pixel_x >= 79) && (pixel_x <= 92) && graduacao_y;
        velocidade_on = video_on && (velocidade_barra || velocidade_marcas);

        // -------------------------------------------------
        // Indicador de direção
        // -------------------------------------------------

        direcao_barra =
            (pixel_y >= 59) &&
            (pixel_y <= 61) &&
            (pixel_x >= 160) &&
            (pixel_x <= 480);

        direcao_marcas =
            (pixel_y >= 50) &&
            (pixel_y <= 61) &&
            (
                ((pixel_x >= 159) && (pixel_x <= 161)) ||
                ((pixel_x >= 199) && (pixel_x <= 201)) ||
                ((pixel_x >= 239) && (pixel_x <= 241)) ||
                ((pixel_x >= 279) && (pixel_x <= 281)) ||
                ((pixel_x >= 319) && (pixel_x <= 321)) ||
                ((pixel_x >= 359) && (pixel_x <= 361)) ||
                ((pixel_x >= 399) && (pixel_x <= 401)) ||
                ((pixel_x >= 439) && (pixel_x <= 441)) ||
                ((pixel_x >= 479) && (pixel_x <= 481))
            );

        direcao_centro =
            (pixel_y >= 62) &&
            (pixel_y <= 68) &&
            (
                (
                    (pixel_x >= 316) &&
                    (pixel_x <= 324) &&
                    (pixel_y == 62)
                )
                ||
                (
                    (pixel_x >= 318) &&
                    (pixel_x <= 322) &&
                    (pixel_y >= 63) &&
                    (pixel_y <= 65)
                )
                ||
                (
                    (pixel_x == 320) &&
                    (pixel_y >= 66) &&
                    (pixel_y <= 68)
                )
            );

        direcao_on =
            video_on &&
            (direcao_barra || direcao_marcas || direcao_centro);

        // -------------------------------------------------
        // Marcador de alvo
        // -------------------------------------------------

        alvo_sup_esq =
            (
                (
                    (pixel_x >= ALVO_X - ALVO_M) &&
                    (pixel_x <= ALVO_X - ALVO_M + CANTO) &&
                    (pixel_y >= ALVO_Y - ALVO_M) &&
                    (pixel_y <= ALVO_Y - ALVO_M + 1)
                )
                ||
                (
                    (pixel_x >= ALVO_X - ALVO_M) &&
                    (pixel_x <= ALVO_X - ALVO_M + 1) &&
                    (pixel_y >= ALVO_Y - ALVO_M) &&
                    (pixel_y <= ALVO_Y - ALVO_M + CANTO)
                )
            );

        alvo_sup_dir =
            (
                (
                    (pixel_x >= ALVO_X + ALVO_M - CANTO) &&
                    (pixel_x <= ALVO_X + ALVO_M) &&
                    (pixel_y >= ALVO_Y - ALVO_M) &&
                    (pixel_y <= ALVO_Y - ALVO_M + 1)
                )
                ||
                (
                    (pixel_x >= ALVO_X + ALVO_M - 1) &&
                    (pixel_x <= ALVO_X + ALVO_M) &&
                    (pixel_y >= ALVO_Y - ALVO_M) &&
                    (pixel_y <= ALVO_Y - ALVO_M + CANTO)
                )
            );

        alvo_inf_esq =
            (
                (
                    (pixel_x >= ALVO_X - ALVO_M) &&
                    (pixel_x <= ALVO_X - ALVO_M + CANTO) &&
                    (pixel_y >= ALVO_Y + ALVO_M - 1) &&
                    (pixel_y <= ALVO_Y + ALVO_M)
                )
                ||
                (
                    (pixel_x >= ALVO_X - ALVO_M) &&
                    (pixel_x <= ALVO_X - ALVO_M + 1) &&
                    (pixel_y >= ALVO_Y + ALVO_M - CANTO) &&
                    (pixel_y <= ALVO_Y + ALVO_M)
                )
            );

        alvo_inf_dir =
            (
                (
                    (pixel_x >= ALVO_X + ALVO_M - CANTO) &&
                    (pixel_x <= ALVO_X + ALVO_M) &&
                    (pixel_y >= ALVO_Y + ALVO_M - 1) &&
                    (pixel_y <= ALVO_Y + ALVO_M)
                )
                ||
                (
                    (pixel_x >= ALVO_X + ALVO_M - 1) &&
                    (pixel_x <= ALVO_X + ALVO_M) &&
                    (pixel_y >= ALVO_Y + ALVO_M - CANTO) &&
                    (pixel_y <= ALVO_Y + ALVO_M)
                )
            );

        alvo_on =
            video_on &&
            (
                alvo_sup_esq ||
                alvo_sup_dir ||
                alvo_inf_esq ||
                alvo_inf_dir
            );

    end

endmodule