// =========================================================
// simbologia_vga.sv
// Simbologia básica do display de avião.
// Geração procedural por coordenadas.
// =========================================================

module simbologia_vga (
    input  logic [9:0] pixel_x,
    input  logic [9:0] pixel_y,
    input  logic       video_on,

    output logic       horizonte_on,
    output logic       altitude_on,
    output logic       direcao_on,
    output logic       alvo_on
);

    logic horizonte_esq;
    logic horizonte_dir;

    logic altitude_barra;
    logic altitude_marcas;

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

        horizonte_esq =
            (pixel_y >= 239) &&
            (pixel_y <= 241) &&
            (pixel_x >= 100) &&
            (pixel_x <= 300);

        horizonte_dir =
            (pixel_y >= 239) &&
            (pixel_y <= 241) &&
            (pixel_x >= 340) &&
            (pixel_x <= 540);

        horizonte_on =
            video_on &&
            (horizonte_esq || horizonte_dir);

        // -------------------------------------------------
        // Escala de altitude
        // -------------------------------------------------

        altitude_barra =
            (pixel_x >= 559) &&
            (pixel_x <= 561) &&
            (pixel_y >= 100) &&
            (pixel_y <= 380);

        altitude_marcas =
            (pixel_x >= 548) &&
            (pixel_x <= 561) &&
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

        altitude_on =
            video_on &&
            (altitude_barra || altitude_marcas);

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