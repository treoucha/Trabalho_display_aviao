// =========================================================
// top_reticula.v
// Top-level: mostra uma retícula centralizada no monitor
// via porta VGA do Nexys A7.
// =========================================================

module top_reticula(
    input  wire        clk,      // CLK100MHZ do board
    output wire [3:0]  VGA_R,
    output wire [3:0]  VGA_G,
    output wire [3:0]  VGA_B,
    output wire         VGA_HS,
    output wire         VGA_VS
);

    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire       video_on;
    wire       hsync, vsync;
    wire       retic;

    vga_controller u_vga (
        .clk_100mhz (clk),
        .pixel_clk  (),
        .hsync      (hsync),
        .vsync      (vsync),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .video_on   (video_on)
    );

    reticula_vga #(
        .ESPESSURA(2),
        .TAMANHO(40),
        .VAO_CENTRAL(6)
    ) u_retic (
        .pixel_x     (pixel_x),
        .pixel_y     (pixel_y),
        .video_on    (video_on),
        .reticula_on (retic)
    );

    assign VGA_HS = hsync;
    assign VGA_VS = vsync;

    // Retícula branca sobre fundo preto
    assign VGA_R = retic ? 4'hF : 4'h0;
    assign VGA_G = retic ? 4'hF : 4'h0;
    assign VGA_B = retic ? 4'hF : 4'h0;

endmodule
