// =========================================================
// top_reticula.sv
// Top-level do display de avião.
// =========================================================

module top_reticula (
    input  logic       clk,

    inout  wire        i2c_sda,
    inout  wire        i2c_scl,

    output wire [3:0]  VGA_R,
    output wire [3:0]  VGA_G,
    output wire [3:0]  VGA_B,

    output wire        VGA_HS,
    output wire        VGA_VS
);

    logic [9:0] pixel_x;
    logic [9:0] pixel_y;
    logic       video_on;

    logic hsync;
    logic vsync;

    logic retic;
    logic horizonte;
    logic altitude;
    logic direcao;
    logic alvo;

    // -----------------------------------------------------
    // SEN-10955 / MMA8452Q
    // -----------------------------------------------------

    logic [7:0] sensor_id;
    logic       sensor_ok;

    mma8452_i2c u_sensor (
        .clk       (clk),
        .i2c_sda   (i2c_sda),
        .i2c_scl   (i2c_scl),
        .who_am_i  (sensor_id),
        .sensor_ok (sensor_ok)
    );

    // -----------------------------------------------------
    // VGA
    // -----------------------------------------------------

    vga_controller u_vga (
        .clk_100mhz (clk),
        .pixel_clk  (),
        .hsync      (hsync),
        .vsync      (vsync),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .video_on   (video_on)
    );

    // -----------------------------------------------------
    // Retícula
    // -----------------------------------------------------

    reticula_vga #(
        .ESPESSURA   (2),
        .TAMANHO     (40),
        .VAO_CENTRAL (6)
    ) u_retic (
        .pixel_x     (pixel_x),
        .pixel_y     (pixel_y),
        .video_on    (video_on),
        .reticula_on (retic)
    );

    // -----------------------------------------------------
    // Simbologia
    // -----------------------------------------------------

    simbologia_vga u_simbologia (
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .video_on     (video_on),

        .horizonte_on (horizonte),
        .altitude_on  (altitude),
        .direcao_on   (direcao),
        .alvo_on      (alvo)
    );

    assign VGA_HS = hsync;
    assign VGA_VS = vsync;

    // -----------------------------------------------------
    // Indicador do sensor
    //
    // Vermelho = sensor não reconhecido
    // Verde = WHO_AM_I == 0x2A
    // -----------------------------------------------------

    logic sensor_status;

    always_comb begin
        sensor_status =
            video_on &&
            (pixel_x >= 20) &&
            (pixel_x <= 35) &&
            (pixel_y >= 20) &&
            (pixel_y <= 35);
    end

    // -----------------------------------------------------
    // Compositor RGB
    // -----------------------------------------------------

    assign VGA_R =
        retic                         ? 4'hF :
        alvo                          ? 4'hF :
        (sensor_status && !sensor_ok) ? 4'hF :
                                        4'h0;

    assign VGA_G =
        retic                              ? 4'hF :
        (horizonte || altitude || direcao) ? 4'hF :
        (sensor_status && sensor_ok)        ? 4'hF :
                                             4'h0;

    assign VGA_B =
        retic ? 4'hF :
                4'h0;

endmodule