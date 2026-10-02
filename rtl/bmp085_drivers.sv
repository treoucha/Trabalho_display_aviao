
module bmp085_driver #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer I2C_FREQ_HZ = 100_000
)(
    input  logic       clk,
    input  logic       rst,

    // Interface para solicitar uma transação
    input  logic       start,
    input  logic       read_not_write, // 1 = leitura; 0 = escrita
    input  logic [6:0] device_addr,    // BMP085: 7'h77
    input  logic [7:0] reg_addr,
    input  logic [7:0] write_data,

    output logic [7:0] read_data,
    output logic       busy,
    output logic       done,
    output logic       ack_error,

    output logic       scl,
    inout  wire        sda
);

    localparam integer DIVIDER =
        CLK_FREQ_HZ / (2 * I2C_FREQ_HZ);

    localparam integer DIV_WIDTH =
        (DIVIDER < 2) ? 1 : $clog2(DIVIDER);

    typedef enum logic [4:0] {
        IDLE,
        START_A, START_B, START_C,
        TX_LOW, TX_HIGH,
        ACK_LOW, ACK_HIGH,
        RESTART_A, RESTART_B, RESTART_C,
        RX_LOW, RX_HIGH,
        NACK_LOW, NACK_HIGH,
        STOP_LOW, STOP_HIGH, STOP_RELEASE
    } state_t;

    state_t state;

    logic [DIV_WIDTH-1:0] divider_count;
    logic tick;

    logic sda_drive_low;
    logic sda_in;

    logic [7:0] shift_reg;
    logic [2:0] bit_index;
    logic [1:0] stage;

    assign sda = sda_drive_low ? 1'b0 : 1'bz;
    assign sda_in = sda;

    // Gera o ritmo das operações I2C
    always_ff @(posedge clk) begin
        if (rst) begin
            divider_count <= '0;
            tick <= 1'b0;
        end else if (divider_count == DIVIDER - 1) begin
            divider_count <= '0;
            tick <= 1'b1;
        end else begin
            divider_count <= divider_count + 1'b1;
            tick <= 1'b0;
        end
    end

    // Controlador de uma transação de um byte
    always_ff @(posedge clk) begin
        if (rst) begin
            state          <= IDLE;
            scl            <= 1'b1;
            sda_drive_low  <= 1'b0;
            shift_reg      <= 8'h00;
            bit_index      <= 3'd7;
            stage          <= 2'd0;
            read_data      <= 8'h00;
            busy           <= 1'b0;
            done           <= 1'b0;
            ack_error      <= 1'b0;
        end else begin
            done <= 1'b0;

            if (tick) begin
                case (state)

                    IDLE: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b0;
                        busy          <= 1'b0;

                        if (start) begin
                            busy      <= 1'b1;
                            ack_error <= 1'b0;
                            stage     <= 2'd0;
                            state     <= START_A;
                        end
                    end

                    // Condição START
                    START_A: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b0;
                        state         <= START_B;
                    end

                    START_B: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b1;
                        state         <= START_C;
                    end

                    START_C: begin
                        scl       <= 1'b0;
                        shift_reg <= {device_addr, 1'b0};
                        bit_index <= 3'd7;
                        state     <= TX_LOW;
                    end

                    // Transmite os 8 bits de um byte
                    TX_LOW: begin
                        scl           <= 1'b0;
                        sda_drive_low <= ~shift_reg[7];
                        state         <= TX_HIGH;
                    end

                    TX_HIGH: begin
                        scl <= 1'b1;

                        if (bit_index == 0) begin
                            state <= ACK_LOW;
                        end else begin
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            bit_index <= bit_index - 1'b1;
                            state     <= TX_LOW;
                        end
                    end

                    // Recebe o ACK do dispositivo
                    ACK_LOW: begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b0;
                        state         <= ACK_HIGH;
                    end

                    ACK_HIGH: begin
                        scl <= 1'b1;

                        if (sda_in !== 1'b0) begin
                            ack_error <= 1'b1;
                            state     <= STOP_LOW;
                        end else begin
                            case (stage)
                                2'd0: begin
                                    stage     <= 2'd1;
                                    shift_reg <= reg_addr;
                                    bit_index <= 3'd7;
                                    state     <= TX_LOW;
                                end

                                2'd1: begin
                                    if (read_not_write) begin
                                        state <= RESTART_A;
                                    end else begin
                                        stage     <= 2'd2;
                                        shift_reg <= write_data;
                                        bit_index <= 3'd7;
                                        state     <= TX_LOW;
                                    end
                                end

                                2'd2: begin
                                    state <= STOP_LOW;
                                end

                                2'd3: begin
                                    shift_reg <= 8'h00;
                                    bit_index <= 3'd7;
                                    state     <= RX_LOW;
                                end

                                default: state <= STOP_LOW;
                            endcase
                        end
                    end

                    // START repetido para leitura
                    RESTART_A: begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b0;
                        state         <= RESTART_B;
                    end

                    RESTART_B: begin
                        scl <= 1'b1;
                        state <= RESTART_C;
                    end

                    RESTART_C: begin
                        sda_drive_low <= 1'b1;
                        stage         <= 2'd3;
                        shift_reg     <= {device_addr, 1'b1};
                        bit_index     <= 3'd7;
                        state         <= TX_LOW;
                    end

                    // Recebe os 8 bits de um byte
                    RX_LOW: begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b0;
                        state         <= RX_HIGH;
                    end

                    RX_HIGH: begin
                        scl       <= 1'b1;
                        shift_reg <= {shift_reg[6:0], sda_in};

                        if (bit_index == 0) begin
                            read_data <= {shift_reg[6:0], sda_in};
                            state     <= NACK_LOW;
                        end else begin
                            bit_index <= bit_index - 1'b1;
                            state     <= RX_LOW;
                        end
                    end

                    // NACK: informa que não serão lidos mais bytes
                    NACK_LOW: begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b0;
                        state         <= NACK_HIGH;
                    end

                    NACK_HIGH: begin
                        scl   <= 1'b1;
                        state <= STOP_LOW;
                    end

                    // Condição STOP
                    STOP_LOW: begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b1;
                        state         <= STOP_HIGH;
                    end

                    STOP_HIGH: begin
                        scl <= 1'b1;
                        state <= STOP_RELEASE;
                    end

                    STOP_RELEASE: begin
                        sda_drive_low <= 1'b0;
                        scl           <= 1'b1;
                        busy          <= 1'b0;
                        done          <= 1'b1;
                        state         <= IDLE;
                    end

                    default: begin
                        state <= IDLE;
                    end
                endcase
            end
        end
    end

endmodule