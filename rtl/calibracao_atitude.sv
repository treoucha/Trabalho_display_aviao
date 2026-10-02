// =========================================================
// calibracao_atitude.sv
//
// Calibracao guiada do sensor inercial.
//
// Etapa 0: sensor reto
// Etapa 1: frente do aviao para cima
// Etapa 2: lado direito para baixo
//
// O modulo descobre automaticamente:
//   - eixo usado para pitch
//   - eixo usado para roll
//   - sentido de cada eixo
// =========================================================

module calibracao_atitude #(
    parameter int DEBOUNCE_CYCLES = 1_000_000
)(
    input logic clk,
    input logic btn_cal,
    input logic dados_validos,

    input logic signed [15:0] accel_x,
    input logic signed [15:0] accel_y,
    input logic signed [15:0] accel_z,

    output logic [1:0] etapa = 2'd0,
    output logic calibrado = 1'b0,

    // 0 = X
    // 1 = Y
    // 2 = Z
    output logic [1:0] eixo_pitch = 2'd0,
    output logic [1:0] eixo_roll  = 2'd1,

    output logic inverte_pitch = 1'b0,
    output logic inverte_roll  = 1'b0,

    output logic signed [15:0] referencia_x = 16'sd0,
    output logic signed [15:0] referencia_y = 16'sd0,
    output logic signed [15:0] referencia_z = 16'sd0
);


    logic signed [16:0] dx;
    logic signed [16:0] dy;
    logic signed [16:0] dz;

    logic [16:0] abs_dx;
    logic [16:0] abs_dy;
    logic [16:0] abs_dz;

    assign dx = $signed({accel_x[15], accel_x})
              - $signed({referencia_x[15], referencia_x});

    assign dy = $signed({accel_y[15], accel_y})
              - $signed({referencia_y[15], referencia_y});

    assign dz = $signed({accel_z[15], accel_z})
              - $signed({referencia_z[15], referencia_z});

    assign abs_dx = dx[16] ? -dx : dx;
    assign abs_dy = dy[16] ? -dy : dy;
    assign abs_dz = dz[16] ? -dz : dz;

    // -----------------------------------------------------
    // Sincronizacao e debounce do BTNC
    // -----------------------------------------------------

    localparam int COUNT_WIDTH =
        (DEBOUNCE_CYCLES > 1) ? $clog2(DEBOUNCE_CYCLES) : 1;

    (* ASYNC_REG = "TRUE" *) logic btn_meta = 1'b0;
    (* ASYNC_REG = "TRUE" *) logic btn_sync = 1'b0;

    logic btn_estavel = 1'b0;
    logic btn_pulso = 1'b0;

    logic [COUNT_WIDTH-1:0] debounce_count = '0;

    always_ff @(posedge clk) begin
        btn_meta <= btn_cal;
        btn_sync <= btn_meta;

        btn_pulso <= 1'b0;

        if (btn_sync == btn_estavel) begin
            debounce_count <= '0;
        end
        else if (debounce_count == COUNT_WIDTH'(DEBOUNCE_CYCLES - 1)) begin
            debounce_count <= '0;
            btn_estavel <= btn_sync;

            if (btn_sync)
                btn_pulso <= 1'b1;
        end
        else begin
            debounce_count <= debounce_count + 1'b1;
        end
    end

    // -----------------------------------------------------
    // Calibracao
    // -----------------------------------------------------

    always_ff @(posedge clk) begin

        if (btn_pulso && dados_validos && !calibrado) begin

            case (etapa)

                // Sensor reto: salva a referencia.
                2'd0: begin
                    referencia_x <= accel_x;
                    referencia_y <= accel_y;
                    referencia_z <= accel_z;

                    etapa <= 2'd1;
                end

                // Frente para cima:
                // eixo que mais mudou sera o pitch.
                2'd1: begin

                    if ((abs_dx >= abs_dy) && (abs_dx >= abs_dz)) begin
                        eixo_pitch <= 2'd0;
                        inverte_pitch <= dx[16];
                    end
                    else if (abs_dy >= abs_dz) begin
                        eixo_pitch <= 2'd1;
                        inverte_pitch <= dy[16];
                    end
                    else begin
                        eixo_pitch <= 2'd2;
                        inverte_pitch <= dz[16];
                    end

                    etapa <= 2'd2;
                end

                // Lado direito para baixo:
                // escolhe o maior eixo que nao seja o pitch.
                2'd2: begin

                    case (eixo_pitch)

                        2'd0: begin
                            if (abs_dy >= abs_dz) begin
                                eixo_roll <= 2'd1;
                                inverte_roll <= dy[16];
                            end
                            else begin
                                eixo_roll <= 2'd2;
                                inverte_roll <= dz[16];
                            end
                        end

                        2'd1: begin
                            if (abs_dx >= abs_dz) begin
                                eixo_roll <= 2'd0;
                                inverte_roll <= dx[16];
                            end
                            else begin
                                eixo_roll <= 2'd2;
                                inverte_roll <= dz[16];
                            end
                        end

                        default: begin
                            if (abs_dx >= abs_dy) begin
                                eixo_roll <= 2'd0;
                                inverte_roll <= dx[16];
                            end
                            else begin
                                eixo_roll <= 2'd1;
                                inverte_roll <= dy[16];
                            end
                        end

                    endcase

                    etapa <= 2'd3;
                    calibrado <= 1'b1;
                end

                default: begin
                    calibrado <= 1'b1;
                end

            endcase
        end
    end

endmodule
