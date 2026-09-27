// MPU-6050 / GY-521: identificação, saída de sleep e leitura dos seis eixos.
// Clock de 100 MHz; I2C open-drain de aproximadamente 100 kHz.
module mpu6050_i2c #(
    parameter logic [6:0] DEVICE_ADDR = 7'h68
)(
    input  logic clk,
    inout  wire  i2c_sda,
    inout  wire  i2c_scl,
    output logic [7:0] who_am_i = 8'h00,
    output logic sensor_ok = 1'b0,
    output logic signed [15:0] accel_x = 16'sd0,
    output logic signed [15:0] accel_y = 16'sd0,
    output logic signed [15:0] accel_z = 16'sd0,
    output logic signed [15:0] gyro_x = 16'sd0,
    output logic signed [15:0] gyro_y = 16'sd0,
    output logic signed [15:0] gyro_z = 16'sd0
);
    logic sda_low = 1'b0;
    logic scl_low = 1'b0;
    assign i2c_sda = sda_low ? 1'b0 : 1'bz;
    assign i2c_scl = scl_low ? 1'b0 : 1'bz;

    (* ASYNC_REG = "TRUE" *) logic [1:0] sda_sync = 2'b11;
    (* ASYNC_REG = "TRUE" *) logic [1:0] scl_sync = 2'b11;
    logic [7:0] scl_high_count = 8'd0;
    wire scl_high_ready = (scl_high_count == 8'd225);
    always_ff @(posedge clk) begin
        // Preserva o tempo alto mínimo mesmo após clock stretching.
        if (!scl_sync[1])
            scl_high_count <= 8'd0;
        else if (!scl_high_ready)
            scl_high_count <= scl_high_count + 1'b1;
        sda_sync <= {sda_sync[0], i2c_sda};
        scl_sync <= {scl_sync[0], i2c_scl};
    end

    // Quatro fases de 2,5 us por bit: preparar, subir, amostrar e descer.
    localparam logic [7:0] CLK_DIV_LAST = 8'd249;
    localparam logic [15:0] STARTUP_TICKS = 16'd40000; // 100 ms
    localparam logic [15:0] POLL_TICKS = 16'd4000;    // 10 ms
    logic [7:0] div_count = 8'd0;
    logic [15:0] idle_count = STARTUP_TICKS;
    logic [12:0] timeout_count = 13'd0;

    typedef enum logic [5:0] {
        ST_IDLE, ST_START_1, ST_START_2, ST_START_HOLD, ST_START_3,
        ST_TX_LOW, ST_TX_HIGH, ST_TX_SAMPLE, ST_TX_FALL,
        ST_ACK_LOW, ST_ACK_HIGH, ST_ACK_SAMPLE, ST_ACK_FALL,
        ST_REP_1, ST_REP_2, ST_REP_3,
        ST_READ_LOW, ST_READ_HIGH, ST_READ_SAMPLE, ST_READ_FALL,
        ST_REPLY_LOW, ST_REPLY_HIGH, ST_REPLY_SAMPLE, ST_REPLY_FALL,
        ST_STOP_1, ST_STOP_2, ST_STOP_3, ST_STOP_RELEASE, ST_DONE
    } state_t;
    state_t state = ST_IDLE;

    typedef enum logic [1:0] { OP_ID, OP_WAKE, OP_DATA } operation_t;
    operation_t operation = OP_ID;
    logic [7:0] tx_data = 8'h00;
    logic [7:0] rx_data = 8'h00;
    logic [7:0] samples [0:13];
    logic [2:0] bit_index = 3'd7;
    logic [3:0] byte_index = 4'd0;
    // 0: endereço W; 1: registrador; 2: endereço R ou dado de escrita.
    logic [1:0] etapa = 2'd0;
    logic ack_error = 1'b0;
    wire last_byte = (operation == OP_ID) || (byte_index == 4'd13);

    always_ff @(posedge clk) begin
        if (div_count == CLK_DIV_LAST) begin
            div_count <= 8'd0;
            if (state != ST_IDLE)
                timeout_count <= timeout_count + 1'b1;

            // Limita a transação a 10 ms, inclusive se SCL ficar preso em zero.
            if ((state != ST_IDLE) && (timeout_count >= 13'd4000)) begin
                sda_low <= 1'b0;
                scl_low <= 1'b0;
                sensor_ok <= 1'b0;
                operation <= OP_ID;
                idle_count <= STARTUP_TICKS;
                state <= ST_IDLE;
            end else begin
                case (state)
                    ST_IDLE: begin
                        sda_low <= 1'b0;
                        scl_low <= 1'b0;
                        timeout_count <= 13'd0;
                        if (idle_count != 0)
                            idle_count <= idle_count - 1'b1;
                        else begin
                            tx_data <= {DEVICE_ADDR, 1'b0};
                            bit_index <= 3'd7;
                            byte_index <= 4'd0;
                            etapa <= 2'd0;
                            ack_error <= 1'b0;
                            state <= ST_START_1;
                        end
                    end
                    ST_START_1: begin
                        if (scl_sync[1] && sda_sync[1])
                            state <= ST_START_2;
                    end
                    ST_START_2: begin
                        sda_low <= 1'b1;
                        state <= ST_START_HOLD;
                    end
                    ST_START_HOLD: state <= ST_START_3;
                    ST_START_3: begin
                        scl_low <= 1'b1;
                        state <= ST_TX_LOW;
                    end
                    ST_TX_LOW: begin
                        sda_low <= ~tx_data[bit_index];
                        state <= ST_TX_HIGH;
                    end
                    ST_TX_HIGH: begin
                        scl_low <= 1'b0;
                        state <= ST_TX_SAMPLE;
                    end
                    ST_TX_SAMPLE: begin
                        if (scl_high_ready)
                            state <= ST_TX_FALL;
                    end
                    ST_TX_FALL: begin
                        scl_low <= 1'b1;
                        if (bit_index == 0)
                            state <= ST_ACK_LOW;
                        else begin
                            bit_index <= bit_index - 1'b1;
                            state <= ST_TX_LOW;
                        end
                    end
                    ST_ACK_LOW: begin
                        sda_low <= 1'b0;
                        state <= ST_ACK_HIGH;
                    end
                    ST_ACK_HIGH: begin
                        scl_low <= 1'b0;
                        state <= ST_ACK_SAMPLE;
                    end
                    ST_ACK_SAMPLE: begin
                        if (scl_high_ready) begin
                            ack_error <= sda_sync[1];
                            state <= ST_ACK_FALL;
                        end
                    end
                    ST_ACK_FALL: begin
                        scl_low <= 1'b1;
                        if (ack_error) begin
                            sensor_ok <= 1'b0;
                            state <= ST_STOP_1;
                        end else begin
                            case (etapa)
                                2'd0: begin
                                    case (operation)
                                        OP_ID: tx_data <= 8'h75;
                                        OP_WAKE: tx_data <= 8'h6B;
                                        default: tx_data <= 8'h3B;
                                    endcase
                                    etapa <= 2'd1;
                                    bit_index <= 3'd7;
                                    state <= ST_TX_LOW;
                                end
                                2'd1: begin
                                    etapa <= 2'd2;
                                    if (operation == OP_WAKE) begin
                                        tx_data <= 8'h00; // PWR_MGMT_1: SLEEP=0.
                                        bit_index <= 3'd7;
                                        state <= ST_TX_LOW;
                                    end else
                                        state <= ST_REP_1;
                                end
                                default: begin
                                    bit_index <= 3'd7;
                                    state <= (operation == OP_WAKE) ? ST_STOP_1 : ST_READ_LOW;
                                end
                            endcase
                        end
                    end
                    ST_REP_1: begin
                        sda_low <= 1'b0;
                        state <= ST_REP_2;
                    end
                    ST_REP_2: begin
                        scl_low <= 1'b0;
                        state <= ST_REP_3;
                    end
                    ST_REP_3: begin
                        if (scl_high_ready) begin
                            tx_data <= {DEVICE_ADDR, 1'b1};
                            bit_index <= 3'd7;
                            state <= ST_START_2;
                        end
                    end
                    ST_READ_LOW: begin
                        sda_low <= 1'b0;
                        state <= ST_READ_HIGH;
                    end
                    ST_READ_HIGH: begin
                        scl_low <= 1'b0;
                        state <= ST_READ_SAMPLE;
                    end
                    ST_READ_SAMPLE: begin
                        if (scl_high_ready) begin
                            rx_data[bit_index] <= sda_sync[1];
                            state <= ST_READ_FALL;
                        end
                    end
                    ST_READ_FALL: begin
                        scl_low <= 1'b1;
                        if (bit_index == 0) begin
                            samples[byte_index] <= rx_data;
                            state <= ST_REPLY_LOW;
                        end else begin
                            bit_index <= bit_index - 1'b1;
                            state <= ST_READ_LOW;
                        end
                    end
                    ST_REPLY_LOW: begin
                        sda_low <= !last_byte; // ACK intermediário; NACK no último byte.
                        state <= ST_REPLY_HIGH;
                    end
                    ST_REPLY_HIGH: begin
                        scl_low <= 1'b0;
                        state <= ST_REPLY_SAMPLE;
                    end
                    ST_REPLY_SAMPLE: begin
                        if (scl_high_ready)
                            state <= ST_REPLY_FALL;
                    end
                    ST_REPLY_FALL: begin
                        scl_low <= 1'b1;
                        if (last_byte)
                            state <= ST_STOP_1;
                        else begin
                            byte_index <= byte_index + 1'b1;
                            bit_index <= 3'd7;
                            state <= ST_READ_LOW;
                        end
                    end
                    ST_STOP_1: begin
                        sda_low <= 1'b1;
                        state <= ST_STOP_2;
                    end
                    ST_STOP_2: begin
                        scl_low <= 1'b0;
                        state <= ST_STOP_3;
                    end
                    ST_STOP_3: begin
                        if (scl_high_ready)
                            state <= ST_STOP_RELEASE;
                    end
                    ST_STOP_RELEASE: begin
                        sda_low <= 1'b0;
                        state <= ST_DONE;
                    end
                    ST_DONE: begin
                        idle_count <= POLL_TICKS;
                        state <= ST_IDLE;
                        if (ack_error) begin
                            sensor_ok <= 1'b0;
                            operation <= OP_ID;
                        end else begin
                            case (operation)
                                OP_ID: begin
                                    who_am_i <= samples[0];
                                    sensor_ok <= 1'b0;
                                    if (samples[0] == 8'h68)
                                        operation <= OP_WAKE;
                                end
                                OP_WAKE: begin
                                    idle_count <= STARTUP_TICKS;
                                    operation <= OP_DATA;
                                end
                                OP_DATA: begin
                                    // Publica uma amostra completa; ignora a temperatura (6 e 7).
                                    accel_x <= $signed({samples[0], samples[1]});
                                    accel_y <= $signed({samples[2], samples[3]});
                                    accel_z <= $signed({samples[4], samples[5]});
                                    gyro_x <= $signed({samples[8], samples[9]});
                                    gyro_y <= $signed({samples[10], samples[11]});
                                    gyro_z <= $signed({samples[12], samples[13]});
                                    sensor_ok <= 1'b1;
                                end
                                default: operation <= OP_ID;
                            endcase
                        end
                    end
                    default: begin
                        sda_low <= 1'b0;
                        scl_low <= 1'b0;
                        sensor_ok <= 1'b0;
                        operation <= OP_ID;
                        idle_count <= STARTUP_TICKS;
                        state <= ST_IDLE;
                    end
                endcase
            end
        end else
            div_count <= div_count + 1'b1;
    end
endmodule
