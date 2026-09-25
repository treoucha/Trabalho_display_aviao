// =========================================================
// reticula_vga.sv
// Retícula central do display.
// VGA 640x480.
// =========================================================

module reticula_vga #(
    parameter int H_RES       = 640,
    parameter int V_RES       = 480,
    parameter int ESPESSURA   = 2,
    parameter int TAMANHO     = 40,
    parameter int VAO_CENTRAL = 6
)(
    input  logic [9:0] pixel_x,
    input  logic [9:0] pixel_y,
    input  logic       video_on,

    output logic       reticula_on
);

    localparam int CENTRO_X = H_RES / 2;
    localparam int CENTRO_Y = V_RES / 2;

    logic linha_horizontal;
    logic linha_vertical;
    logic fora_do_vao;

    always_comb begin

        linha_horizontal =
            (pixel_y >= CENTRO_Y - ESPESSURA / 2) &&
            (pixel_y <= CENTRO_Y + ESPESSURA / 2) &&
            (pixel_x >= CENTRO_X - TAMANHO) &&
            (pixel_x <= CENTRO_X + TAMANHO);

        linha_vertical =
            (pixel_x >= CENTRO_X - ESPESSURA / 2) &&
            (pixel_x <= CENTRO_X + ESPESSURA / 2) &&
            (pixel_y >= CENTRO_Y - TAMANHO) &&
            (pixel_y <= CENTRO_Y + TAMANHO);

        fora_do_vao =
            !(
                (pixel_x >= CENTRO_X - VAO_CENTRAL) &&
                (pixel_x <= CENTRO_X + VAO_CENTRAL) &&
                (pixel_y >= CENTRO_Y - VAO_CENTRAL) &&
                (pixel_y <= CENTRO_Y + VAO_CENTRAL)
            );

        reticula_on =
            video_on &&
            (linha_horizontal || linha_vertical) &&
            ((VAO_CENTRAL == 0) ? 1'b1 : fora_do_vao);

    end

endmodule