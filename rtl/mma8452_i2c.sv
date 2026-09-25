// =========================================================
// mma8452_i2c.sv
//
// Leitura do registrador WHO_AM_I do MMA8452Q / SEN-10955.
//
// Endereco I2C padrão: 0x1D
// WHO_AM_I: 0x0D
// Resposta esperada: 0x2A
//
// Clock FPGA: 100 MHz
// I2C: aproximadamente 100 kHz
// =========================================================

module mma8452_i2c #(
    parameter logic [6:0] DEVICE_ADDR = 7'h1D
)(
    input  logic clk,

    inout  wire  i2c_sda,
    inout  wire  i2c_scl,

    output logic [7:0] who_am_i  = 8'h00,
    output logic       sensor_ok = 1'b0
);

    // -----------------------------------------------------
    // Open-drain
    //
    // 1 = puxar linha para 0
    // 0 = liberar linha
    // -----------------------------------------------------

    logic sda_low = 1'b0;
    logic scl_low = 1'b0;

    assign i2c_sda = sda_low ? 1'b0 : 1'bz;
    assign i2c_scl = scl_low ? 1'b0 : 1'bz;

    // -----------------------------------------------------
    // Divisor
    // 100 MHz / 500 = tick a cada 5 us
    // -----------------------------------------------------

    localparam int CLK_DIV = 500;

    logic [15:0] div_count = 16'd0;
    logic        tick;

    assign tick = (div_count == CLK_DIV - 1);

    // -----------------------------------------------------
    // Máquina de estados
    // -----------------------------------------------------

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

    state_t state = ST_IDLE;

    logic [7:0] tx_data = 8'h00;
    logic [7:0] rx_data = 8'h00;

    logic [2:0] bit_index = 3'd7;

    // 0 = endereço de escrita
    // 1 = registrador WHO_AM_I
    // 2 = endereço de leitura
    logic [1:0] etapa = 2'd0;

    logic ack_error = 1'b0;

    // Aproximadamente 10 ms entre tentativas
    logic [11:0] idle_count = 12'd0;

    // -----------------------------------------------------
    // Máquina I2C
    // -----------------------------------------------------

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

                        state <= ST_START_1;

                    end
                    else begin
                        idle_count <= idle_count + 1'b1;
                    end
                end

                // -----------------------------------------
                // START
                // -----------------------------------------

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

                // -----------------------------------------
                // Transmissão
                // -----------------------------------------

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
                        state     <= ST_TX_LOW;
                    end
                end

                // -----------------------------------------
                // ACK
                // -----------------------------------------

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

                        2'd0: begin
                            tx_data   <= 8'h0D;
                            bit_index <= 3'd7;
                            etapa     <= 2'd1;

                            state <= ST_TX_LOW;
                        end

                        2'd1: begin
                            etapa <= 2'd2;

                            state <= ST_REP_1;
                        end

                        2'd2: begin
                            bit_index <= 3'd7;
                            rx_data   <= 8'h00;

                            state <= ST_READ_LOW;
                        end

                        default: begin
                            state <= ST_STOP_1;
                        end

                    endcase
                end

                // -----------------------------------------
                // Repeated START
                // -----------------------------------------

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

                // -----------------------------------------
                // Leitura
                // -----------------------------------------

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
                        state     <= ST_READ_LOW;
                    end
                end

                // -----------------------------------------
                // NACK
                // -----------------------------------------

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

                // -----------------------------------------
                // STOP
                // -----------------------------------------

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

                    who_am_i <= rx_data;

                    if ((!ack_error) && (rx_data == 8'h2A))
                        sensor_ok <= 1'b1;
                    else
                        sensor_ok <= 1'b0;

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