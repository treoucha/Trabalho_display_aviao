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

    always_comb begin

        // -------------------------------------------------
        // Horizonte artificial
        // -------------------------------------------------

        // Inclinação linear da simbologia; escalas e retículo permanecem fixos.
        deslocamento_roll = (($signed({12'b0, pixel_x}) - 22'sd320) * 22'(roll_q8)) >>> 8;
        distancia_horizonte = $signed({12'b0, pixel_y}) - $signed({12'b0, horizonte_y}) - deslocamento_roll;

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
            (horizonte_esq || horizonte_dir || marcas_superiores || marcas_inferiores);

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