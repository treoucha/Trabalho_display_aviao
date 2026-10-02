// =========================================================
// mpu_inercial_i2c.sv
//
// Interface I2C minima para sensores MPU-6050/MPU-6500
// compativeis.
//
// Fluxo:
//   1. Le WHO_AM_I
//   2. Escreve 0x00 em PWR_MGMT_1 para acordar
//   3. Le AX, AY e AZ continuamente
//
// Clock FPGA: 100 MHz
// I2C: aproximadamente 100 kHz
// =========================================================

module mpu_inercial_i2c #(
    parameter logic [6:0] DEVICE_ADDR = 7'h68
)(
    input logic clk,

    inout wire i2c_sda,
    inout wire i2c_scl,

    output logic [7:0] who_am_i = 8'h00,
    output logic sensor_ok = 1'b0,
    output logic sensor_awake = 1'b0,
    output logic dados_validos = 1'b0,

    output logic signed [15:0] accel_x = 16'sd0,
    output logic signed [15:0] accel_y = 16'sd0,
    output logic signed [15:0] accel_z = 16'sd0
);

    logic sda_low = 1'b0;
    logic scl_low = 1'b0;

    assign i2c_sda = sda_low ? 1'b0 : 1'bz;
    assign i2c_scl = scl_low ? 1'b0 : 1'bz;

    // Tick de 5 us. Duas fases formam aproximadamente 100 kHz.
    localparam int CLK_DIV = 500;

    logic [15:0] div_count = 16'd0;
    logic tick;

    assign tick = (div_count == CLK_DIV - 1);

    typedef enum logic [4:0] {
        ST_IDLE,
        ST_START_1,
        ST_START_2,
        ST_START_3,
        ST_TX_LOW,
        ST_TX_HIGH,
        ST_ACK_LOW,
        ST_ACK_HIGH,
        ST_REP_1,
        ST_REP_2,
        ST_REP_3,
        ST_READ_LOW,
        ST_READ_HIGH,
        ST_NACK_LOW,
        ST_NACK_HIGH,
        ST_STOP_1,
        ST_STOP_2,
        ST_STOP_3
    } state_t;

    typedef enum logic [3:0] {
        CMD_WHO,
        CMD_WAKE,
        CMD_AX_H,
        CMD_AX_L,
        CMD_AY_H,
        CMD_AY_L,
        CMD_AZ_H,
        CMD_AZ_L
    } cmd_t;

    state_t state = ST_IDLE;
    cmd_t   cmd   = CMD_WHO;

    logic [7:0] tx_data    = 8'h00;
    logic [7:0] rx_data    = 8'h00;
    logic [7:0] reg_addr   = 8'h75;
    logic [7:0] write_data = 8'h00;

    logic       op_read   = 1'b1;
    logic [2:0] bit_index = 3'd7;
    logic [1:0] etapa     = 2'd0;
    logic       ack_error = 1'b0;

    // 2000 * 5 us = aproximadamente 10 ms entre transacoes.
    // E lento de proposito nesta primeira validacao.
    logic [11:0] idle_count = 12'd0;

    always_ff @(posedge clk) begin

        if (tick) begin
            div_count <= 16'd0;

            case (state)

                ST_IDLE: begin
                    sda_low <= 1'b0;
                    scl_low <= 1'b0;

                    if (idle_count >= 12'd2000) begin
                        idle_count <= 12'd0;

                        tx_data   <= {DEVICE_ADDR, 1'b0};
                        bit_index <= 3'd7;
                        etapa     <= 2'd0;
                        ack_error <= 1'b0;

                        case (cmd)

                            CMD_WHO: begin
                                reg_addr <= 8'h75;
                                op_read  <= 1'b1;
                            end

                            CMD_WAKE: begin
                                reg_addr   <= 8'h6B;
                                write_data <= 8'h00;
                                op_read    <= 1'b0;
                            end

                            CMD_AX_H: begin
                                reg_addr <= 8'h3B;
                                op_read  <= 1'b1;
                            end

                            CMD_AX_L: begin
                                reg_addr <= 8'h3C;
                                op_read  <= 1'b1;
                            end

                            CMD_AY_H: begin
                                reg_addr <= 8'h3D;
                                op_read  <= 1'b1;
                            end

                            CMD_AY_L: begin
                                reg_addr <= 8'h3E;
                                op_read  <= 1'b1;
                            end

                            CMD_AZ_H: begin
                                reg_addr <= 8'h3F;
                                op_read  <= 1'b1;
                            end

                            CMD_AZ_L: begin
                                reg_addr <= 8'h40;
                                op_read  <= 1'b1;
                            end

                            default: begin
                                reg_addr <= 8'h75;
                                op_read  <= 1'b1;
                            end

                        endcase

                        state <= ST_START_1;
                    end
                    else begin
                        idle_count <= idle_count + 1'b1;
                    end
                end

                // START
                ST_START_1: begin
                    sda_low <= 1'b0;
                    scl_low <= 1'b0;
                    state <= ST_START_2;
                end

                ST_START_2: begin
                    sda_low <= 1'b1;
                    scl_low <= 1'b0;
                    state <= ST_START_3;
                end

                ST_START_3: begin
                    scl_low <= 1'b1;
                    state <= ST_TX_LOW;
                end

                // TX
                ST_TX_LOW: begin
                    scl_low <= 1'b1;
                    sda_low <= ~tx_data[bit_index];
                    state <= ST_TX_HIGH;
                end

                ST_TX_HIGH: begin
                    scl_low <= 1'b0;

                    if (bit_index == 3'd0) begin
                        state <= ST_ACK_LOW;
                    end
                    else begin
                        bit_index <= bit_index - 1'b1;
                        state <= ST_TX_LOW;
                    end
                end

                // ACK
                ST_ACK_LOW: begin
                    scl_low <= 1'b1;
                    sda_low <= 1'b0;
                    state <= ST_ACK_HIGH;
                end

                ST_ACK_HIGH: begin
                    scl_low <= 1'b0;

                    if (i2c_sda != 1'b0)
                        ack_error <= 1'b1;

                    case (etapa)

                        // Endereco do dispositivo enviado.
                        2'd0: begin
                            tx_data   <= reg_addr;
                            bit_index <= 3'd7;
                            etapa     <= 2'd1;
                            state     <= ST_TX_LOW;
                        end

                        // Endereco do registrador enviado.
                        2'd1: begin
                            if (op_read) begin
                                etapa <= 2'd2;
                                state <= ST_REP_1;
                            end
                            else begin
                                tx_data   <= write_data;
                                bit_index <= 3'd7;
                                etapa     <= 2'd3;
                                state     <= ST_TX_LOW;
                            end
                        end

                        // Endereco de leitura enviado.
                        2'd2: begin
                            bit_index <= 3'd7;
                            rx_data   <= 8'h00;
                            state     <= ST_READ_LOW;
                        end

                        // Dado da escrita enviado.
                        2'd3: begin
                            state <= ST_STOP_1;
                        end

                        default: begin
                            state <= ST_STOP_1;
                        end

                    endcase
                end

                // Repeated START para leitura.
                ST_REP_1: begin
                    scl_low <= 1'b1;
                    sda_low <= 1'b0;
                    state <= ST_REP_2;
                end

                ST_REP_2: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    state <= ST_REP_3;
                end

                ST_REP_3: begin
                    sda_low <= 1'b1;

                    tx_data   <= {DEVICE_ADDR, 1'b1};
                    bit_index <= 3'd7;

                    state <= ST_START_3;
                end

                // RX
                ST_READ_LOW: begin
                    scl_low <= 1'b1;
                    sda_low <= 1'b0;
                    state <= ST_READ_HIGH;
                end

                ST_READ_HIGH: begin
                    scl_low <= 1'b0;

                    rx_data[bit_index] <= i2c_sda;

                    if (bit_index == 3'd0) begin
                        state <= ST_NACK_LOW;
                    end
                    else begin
                        bit_index <= bit_index - 1'b1;
                        state <= ST_READ_LOW;
                    end
                end

                // Final da leitura de um byte.
                ST_NACK_LOW: begin
                    scl_low <= 1'b1;
                    sda_low <= 1'b0;
                    state <= ST_NACK_HIGH;
                end

                ST_NACK_HIGH: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    state <= ST_STOP_1;
                end

                // STOP
                ST_STOP_1: begin
                    scl_low <= 1'b1;
                    sda_low <= 1'b1;
                    state <= ST_STOP_2;
                end

                ST_STOP_2: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b1;
                    state <= ST_STOP_3;
                end

                ST_STOP_3: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;

                    if (ack_error) begin
                        sensor_ok     <= 1'b0;
                        sensor_awake  <= 1'b0;
                        dados_validos <= 1'b0;
                        cmd           <= CMD_WHO;
                    end
                    else begin

                        case (cmd)

                            CMD_WHO: begin
                                who_am_i <= rx_data;

                                if ((rx_data == 8'h68) ||
                                    (rx_data == 8'h70)) begin
                                    sensor_ok <= 1'b1;
                                    cmd <= CMD_WAKE;
                                end
                                else begin
                                    sensor_ok <= 1'b0;
                                    cmd <= CMD_WHO;
                                end
                            end

                            CMD_WAKE: begin
                                sensor_awake  <= 1'b1;
                                dados_validos <= 1'b0;
                                cmd <= CMD_AX_H;
                            end

                            CMD_AX_H: begin
                                accel_x[15:8] <= rx_data;
                                cmd <= CMD_AX_L;
                            end

                            CMD_AX_L: begin
                                accel_x[7:0] <= rx_data;
                                cmd <= CMD_AY_H;
                            end

                            CMD_AY_H: begin
                                accel_y[15:8] <= rx_data;
                                cmd <= CMD_AY_L;
                            end

                            CMD_AY_L: begin
                                accel_y[7:0] <= rx_data;
                                cmd <= CMD_AZ_H;
                            end

                            CMD_AZ_H: begin
                                accel_z[15:8] <= rx_data;
                                cmd <= CMD_AZ_L;
                            end

                            CMD_AZ_L: begin
                                accel_z[7:0] <= rx_data;
                                dados_validos <= 1'b1;
                                cmd <= CMD_AX_H;
                            end

                            default: begin
                                cmd <= CMD_WHO;
                            end

                        endcase
                    end

                    state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end

            endcase
        end
        else begin
            div_count <= div_count + 1'b1;
        end
    end

endmodule
