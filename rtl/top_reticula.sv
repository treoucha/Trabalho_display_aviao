// =========================================================
// top_reticula.sv
// Top-level do display de avião.
// =========================================================

module top_reticula (
    input  logic        clk,
    input  logic [1:0]  btn_heading,  // BTNU=+10, BTND=-10
    input  logic [15:12] sw,        // reservados; atitude vem do MPU6050
    input  logic        display_mode, // SW0: 0=NORMAL, 1=DECLUTTER

    inout  wire         i2c_sda,
    inout  wire         i2c_scl,

    output wire [3:0]   VGA_R,
    output wire [3:0]   VGA_G,
    output wire [3:0]   VGA_B,

    output wire         VGA_HS,
    output wire         VGA_VS
);

    logic [9:0] pixel_x;
    logic [9:0] pixel_y;
    logic       video_on;

    wire pixel_clk;
    wire declutter;
    controle_modo u_modo (
        .clk(pixel_clk), .display_mode(display_mode),
        .atualizar((pixel_x == 0) && (pixel_y == 480)),
        .declutter(declutter)
    );

    wire [9:0] horizonte_y;
    wire signed [9:0] roll_q8;
    wire [9:0] velocidade_kt;
    wire [16:0] altitude_ft;
    wire [8:0] heading_deg;
    wire signed [10:0] pitch_px_entrada;
    wire signed [9:0] roll_q8_entrada;

    wire [56:0] amostra_pixel;
    wire amostra_valida;
    wire entrada_pronta;
    wire [8:0] heading_entrada;

    controle_heading u_heading (
        .clk         (clk),
        .btn         (btn_heading),
        .heading_deg (heading_entrada)
    );
    // Mantém a última atitude e transmite também alterações de heading.
    // Ordem: velocidade(10), altitude(17), pitch(11), roll(10), heading(9).
    entrada_hud u_entrada (
        .clk_origem(clk), .clk_destino(pixel_clk),
        .valido(1'b1),
        .dados({10'd280, 17'd36000, pitch_px_entrada, roll_q8_entrada, heading_entrada}),
        .pronto(entrada_pronta),
        .valido_destino(amostra_valida), .dados_destino(amostra_pixel)
    );
    dados_hud u_dados (
        .clk(pixel_clk),
        .atualizar_quadro((pixel_x == 0) && (pixel_y == 480)),
        .dados_validos(amostra_valida),
        .velocidade_kt_in(amostra_pixel[56:47]),
        .altitude_ft_in(amostra_pixel[46:30]),
        .pitch_px_in($signed(amostra_pixel[29:19])),
        .roll_q8_in($signed(amostra_pixel[18:9])),
        .heading_deg_in(amostra_pixel[8:0]),
        .velocidade_kt(velocidade_kt), .altitude_ft(altitude_ft),
        .horizonte_y(horizonte_y),
        .roll_q8(roll_q8),
        .heading_deg(heading_deg)
    );

    wire numeros;
    numeros_hud u_numeros (
        .pixel_x(pixel_x), .pixel_y(pixel_y), .video_on(video_on),
        .velocidade_kt(velocidade_kt), .altitude_ft(altitude_ft),
        .numeros_on(numeros)
    );

    logic hsync;
    logic vsync;

    logic retic;
    logic horizonte;
    logic altitude;
    logic velocidade;
    logic direcao;
    logic alvo;

    // -----------------------------------------------------
    // MPU6050: leituras completas a 100 MHz.
    // -----------------------------------------------------
    wire [7:0] sensor_id;
    wire sensor_ok, sensor_amostra, calibrado, atitude_ok, nova_atitude;
    wire signed [15:0] ax, ay, az, gx, gy, gz;
    mpu6050_i2c u_sensor (
        .clk(clk), .i2c_sda(i2c_sda), .i2c_scl(i2c_scl),
        .who_am_i(sensor_id), .sensor_ok(sensor_ok), .amostra_valida(sensor_amostra),
        .accel_x(ax), .accel_y(ay), .accel_z(az),
        .gyro_x(gx), .gyro_y(gy), .gyro_z(gz)
    );
    atitude_mpu6050 u_atitude (
        .clk(clk), .sensor_ok(sensor_ok), .amostra_valida(sensor_amostra),
        .accel_x(ax), .accel_y(ay), .accel_z(az),
        .gyro_x(gx), .gyro_y(gy), .gyro_z(gz),
        .calibrado(calibrado), .atitude_ok(atitude_ok), .nova_atitude(nova_atitude),
        .pitch_px(pitch_px_entrada), .roll_q8(roll_q8_entrada)
    );
    (* ASYNC_REG = "TRUE" *) logic status_meta = 0, status_sync = 0;
    logic sensor_pronto = 0;
    always_ff @(posedge pixel_clk) begin
        status_meta <= sensor_ok && atitude_ok && calibrado;
        status_sync <= status_meta;
        if (pixel_x == 0 && pixel_y == 480) sensor_pronto <= status_sync;
    end

    // -----------------------------------------------------
    // VGA
    // -----------------------------------------------------

    vga_controller u_vga (
        .clk_100mhz (clk),
        .pixel_clk  (pixel_clk),
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
        .ESPESSURA   (1),
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
        .horizonte_y  (horizonte_y),
        .roll_q8      (roll_q8),
        .heading_deg  (heading_deg),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .video_on     (video_on),

        .horizonte_on (horizonte),
        .altitude_on  (altitude),
        .velocidade_on (velocidade),
        .direcao_on   (direcao),
        .alvo_on      (alvo)
    );

    assign VGA_HS = hsync;
    assign VGA_VS = vsync;

    // -----------------------------------------------------
    // Indicador do sensor
    //
    // Vermelho = sem atitude válida ou calibrando; verde = pronto.
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
        retic                         ? 4'h0 :
        alvo                          ? 4'hF :
        (sensor_status && !declutter && !sensor_pronto) ? 4'hF :
                                        4'h0;

    assign VGA_G =
        retic                              ? 4'hF :
        (horizonte || (!declutter && (altitude || velocidade || direcao || numeros))) ? 4'hF :
        (sensor_status && !declutter && sensor_pronto)        ? 4'hF :
                                             4'h0;

    assign VGA_B = 4'h0;

endmodule
