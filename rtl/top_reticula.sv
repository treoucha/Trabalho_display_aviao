// =========================================================
// top_reticula.sv
// Top-level do display de avião.
// =========================================================

module top_reticula (
    input  logic        clk,
    input  logic [1:0]  btn_heading,  // BTNU=+10, BTND=-10
    input  logic [15:12] sw,        // pitch e roll
    input  logic        display_mode, // SW0: 0=NORMAL, 1=DECLUTTER

    // Entradas analogicas do joystick pelo JXADC.
    input  wire         vauxp3,
    input  wire         vauxn3,
    input  wire         vauxp10,
    input  wire         vauxn10,

    // LEDs temporarios para validacao do joystick.
    output wire [3:0]   JOY_LED,

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

    // -----------------------------------------------------
    // Joystick analogico KY-023 via XADC
    // -----------------------------------------------------

    logic [11:0] joystick_x_raw;
    logic [11:0] joystick_y_raw;

    logic joystick_x_menos;
    logic joystick_x_mais;
    logic joystick_y_menos;
    logic joystick_y_mais;

    joystick_xadc u_joystick_xadc (
        .clk     (clk),
        .vauxp3  (vauxp3),
        .vauxn3  (vauxn3),
        .vauxp10 (vauxp10),
        .vauxn10 (vauxn10),
        .x_raw   (joystick_x_raw),
        .y_raw   (joystick_y_raw)
    );

    controle_joystick u_controle_joystick (
        .clk     (clk),
        .x_raw   (joystick_x_raw),
        .y_raw   (joystick_y_raw),

        // Botao ainda nao esta conectado.
        .sw_n    (1'b1),

        .x_menos (joystick_x_menos),
        .x_mais  (joystick_x_mais),
        .y_menos (joystick_y_menos),
        .y_mais  (joystick_y_mais),
        .botao   ()
    );

    // LD0=X-, LD1=X+, LD2=Y-, LD3=Y+.
    // Diagnostico temporario:
    // LD3..LD0 mostram x_raw[11:8].
    assign JOY_LED[0] = joystick_x_menos;
    assign JOY_LED[1] = joystick_x_mais;
    assign JOY_LED[2] = joystick_y_menos;
    assign JOY_LED[3] = joystick_y_mais;

    wire pixel_clk;
    wire declutter;
    controle_modo u_modo (
        .clk(pixel_clk), .display_mode(display_mode),
        .atualizar((pixel_x == 0) && (pixel_y == 480)),
        .declutter(declutter)
    );

    (* ASYNC_REG = "TRUE" *) logic [1:0] horizonte_meta = '0;
    (* ASYNC_REG = "TRUE" *) logic [1:0] horizonte_sync = '0;
    (* ASYNC_REG = "TRUE" *) logic [1:0] roll_meta = '0;
    (* ASYNC_REG = "TRUE" *) logic [1:0] roll_sync = '0;
    wire [9:0] horizonte_y;
    wire signed [9:0] roll_q8;
    wire [9:0] velocidade_kt;
    wire [16:0] altitude_ft;
    wire [8:0] heading_deg;
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

    wire [56:0] amostra_pixel;
    wire amostra_valida;
    wire entrada_pronta;
    wire [8:0] heading_entrada;

    controle_heading u_heading (
        .clk         (clk),
        .btn         (btn_heading),
        .heading_deg (heading_entrada)
    );
    // Ordem: velocidade(10), altitude(17), pitch(11), roll(10), heading(9)..
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
        retic                         ? 4'h0 :
        alvo                          ? 4'hF :
        (sensor_status && !declutter && !sensor_ok) ? 4'hF :
                                        4'h0;

    assign VGA_G =
        retic                              ? 4'hF :
        (horizonte || (!declutter && (altitude || velocidade || direcao || numeros))) ? 4'hF :
        (sensor_status && !declutter && sensor_ok)        ? 4'hF :
                                             4'h0;

    assign VGA_B = 4'h0;

endmodule
