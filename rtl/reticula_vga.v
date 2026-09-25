// =========================================================
// reticula_vga.v
// Gera uma retícula (crosshair) centralizada na tela.
// Pensado para VGA 640x480 @ 60Hz (pixel clock = 25 MHz)
// Nexys A7
// =========================================================

module reticula_vga #(
    parameter H_RES        = 640,   // resolução horizontal
    parameter V_RES        = 480,   // resolução vertical
    parameter ESPESSURA    = 2,     // espessura da linha (pixels)
    parameter TAMANHO      = 40,    // metade do comprimento de cada braço
    parameter VAO_CENTRAL  = 6      // vão no meio (estilo mira de jogo); 0 = sem vão
)(
    input  wire [9:0] pixel_x,   // coordenada X atual (vinda do contador VGA)
    input  wire [9:0] pixel_y,   // coordenada Y atual (vinda do contador VGA)
    input  wire       video_on,  // ativo somente na área visível
    output wire        reticula_on // '1' quando o pixel pertence à retícula
);

    localparam CENTRO_X = H_RES/2;
    localparam CENTRO_Y = V_RES/2;

    wire dentro_faixa_x;
    wire dentro_faixa_y;
    wire linha_horizontal;
    wire linha_vertical;
    wire fora_do_vao;

    // TODO: Ajustar os limites para ESPESSURA=2 desenhar duas linhas de pixels, não três.
    // TODO: Testar espessuras pares/ímpares, vão central e bloqueio fora da área visível.
    // Linha horizontal: pixel_y perto do centro, pixel_x dentro do comprimento do braço
    assign linha_horizontal =
        (pixel_y >= CENTRO_Y - ESPESSURA/2) &&
        (pixel_y <= CENTRO_Y + ESPESSURA/2) &&
        (pixel_x >= CENTRO_X - TAMANHO) &&
        (pixel_x <= CENTRO_X + TAMANHO);

    // Linha vertical: pixel_x perto do centro, pixel_y dentro do comprimento do braço
    assign linha_vertical =
        (pixel_x >= CENTRO_X - ESPESSURA/2) &&
        (pixel_x <= CENTRO_X + ESPESSURA/2) &&
        (pixel_y >= CENTRO_Y - TAMANHO) &&
        (pixel_y <= CENTRO_Y + TAMANHO);

    // Vão central opcional (deixa um espaço vazio no meio da mira)
    assign fora_do_vao =
        !((pixel_x >= CENTRO_X - VAO_CENTRAL) && (pixel_x <= CENTRO_X + VAO_CENTRAL) &&
          (pixel_y >= CENTRO_Y - VAO_CENTRAL) && (pixel_y <= CENTRO_Y + VAO_CENTRAL));

    assign reticula_on = video_on && (linha_horizontal || linha_vertical) &&
                          (VAO_CENTRAL == 0 ? 1'b1 : fora_do_vao);

endmodule
