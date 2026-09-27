// =========================================================
// top_reticula.sv
// Top-level do display de avião.
// =========================================================

module top_reticula (
    input  logic       clk,
    input  logic [2:0] btn_rgb,  // BTNL=R, BTNC=G, BTNR=B
    input logic [15:0] sw,     // [11:0]=RGB, [12:13]=pitch, [14:15]=roll


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

    wire pixel_clk;
    wire [11:0] cor_reticula;

    controle_cor u_cor (
        .clk (pixel_clk),
        .btn_rgb (btn_rgb),
        .sw (sw[11:0]),
        .atualizar ((pixel_x == 0) && (pixel_y == 480)),
        .rgb (cor_reticula)
    );

    (* ASYNC_REG = "TRUE" *) logic [1:0] horizonte_meta = '0;
    (* ASYNC_REG = "TRUE" *) logic [1:0] horizonte_sync = '0;
    (* ASYNC_REG = "TRUE" *) logic [1:0] roll_meta = '0;
    (* ASYNC_REG = "TRUE" *) logic [1:0] roll_sync = '0;
    wire [9:0] horizonte_y;
    wire signed [9:0] roll_q8;
    wire [9:0] velocidade_kt;
    wire [16:0] altitude_ft;
    logic signed [10:0] pitch_px_entrada;
    logic signed [9:0] roll_q8_entrada;

    always_ff @(posedge clk) begin
        horizonte_meta <= sw[13:12];
        horizonte_sync <= horizonte_meta;

        roll_meta <= sw[15:14];
        roll_sync <= roll_meta;
    end

    // Fonte simulada a 100 MHz. Substituir por dados processados nesse domínio.
    always_comb begin
        case (horizonte_sync)
            2'b01: pitch_px_entrada = -11'sd40;
            2'b10: pitch_px_entrada = 11'sd40;
            default: pitch_px_entrada = 11'sd0;
        endcase
    end

    always_comb begin
        case (roll_sync)
            2'b01: roll_q8_entrada = -10'sd64; // SW14: inclina para esquerda
            2'b10: roll_q8_entrada =  10'sd64; // SW15: inclina para direita
            default: roll_q8_entrada = 10'sd0;
        endcase
    end

    wire [47:0] amostra_pixel;
    wire amostra_valida;
    wire entrada_pronta;
    // Ordem do barramento: velocidade(10), altitude(17), pitch(11), roll(10).
    entrada_hud u_entrada (
        .clk_origem(clk), .clk_destino(pixel_clk),
        .valido(1'b1),
        .dados({10'd280, 17'd36000, pitch_px_entrada, roll_q8_entrada}),
        .pronto(entrada_pronta),
        .valido_destino(amostra_valida), .dados_destino(amostra_pixel)
    );
    dados_hud u_dados (
        .clk(pixel_clk),
        .atualizar_quadro((pixel_x == 0) && (pixel_y == 480)),
        .dados_validos(amostra_valida),
        .velocidade_kt_in(amostra_pixel[47:38]), .altitude_ft_in(amostra_pixel[37:21]),
        .pitch_px_in($signed(amostra_pixel[20:10])), .roll_q8_in($signed(amostra_pixel[9:0])),
        .velocidade_kt(velocidade_kt), .altitude_ft(altitude_ft),
        .horizonte_y(horizonte_y), .roll_q8(roll_q8)
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
        .horizonte_y  (horizonte_y),
        .roll_q8      (roll_q8),
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
        retic                         ? cor_reticula[3:0] :
        alvo                          ? 4'hF :
        (sensor_status && !sensor_ok) ? 4'hF :
                                        4'h0;

    assign VGA_G =
        retic                              ? cor_reticula[7:4] :
        (horizonte || altitude || velocidade || direcao || numeros) ? 4'hF :
        (sensor_status && sensor_ok)        ? 4'hF :
                                             4'h0;

    assign VGA_B =
        retic ? cor_reticula[11:8] :
                4'h0;

endmodule
