module bmp085_controller #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer CONVERSION_WAIT_MS = 5,
    parameter integer OSS_VALUE = 0
)(
    input  logic clk,
    input  logic rst,

    // Interface fisica I2C
    output logic scl,
    inout  wire  sda,

    // Coeficientes de calibracao para bmp085_i2c.sv
    output logic calib_valid,
    output logic signed [15:0] ac1,
    output logic signed [15:0] ac2,
    output logic signed [15:0] ac3,
    output logic        [15:0] ac4,
    output logic        [15:0] ac5,
    output logic        [15:0] ac6,
    output logic signed [15:0] b1,
    output logic signed [15:0] b2,
    output logic signed [15:0] mb,
    output logic signed [15:0] mc,
    output logic signed [15:0] md,

    // Medicoes brutas para bmp085_i2c.sv
    output logic measurement_valid,
    output logic [15:0] ut,
    output logic [19:0] up,
    output logic [1:0] oss,

    output logic sensor_ready,
    output logic i2c_error
);

    localparam logic [6:0] BMP085_ADDR = 7'h77;
    localparam logic [1:0] OSS_CFG = OSS_VALUE;

    localparam integer WAIT_CYCLES =
        (CLK_FREQ_HZ / 1000) * CONVERSION_WAIT_MS;

    // Interface do driver I2C
    logic driver_start;
    logic driver_read_not_write;
    logic [7:0] driver_reg_addr;
    logic [7:0] driver_write_data;
    logic [7:0] driver_read_data;
    logic driver_busy;
    logic driver_done;
    logic driver_ack_error;

    // Armazenamento dos 22 bytes de calibracao
    logic [7:0] calib_bytes [0:21];
    logic [4:0] calib_index;

    // Bytes de temperatura e pressao
    logic [7:0] ut_msb;
    logic [7:0] pressure_msb;
    logic [7:0] pressure_lsb;

    // Temporizador das conversoes
    logic [31:0] wait_counter;

    typedef enum logic [3:0] {
        CAL_ISSUE,
        CAL_WAIT,
        CAL_PARSE,
        TEMP_CMD_ISSUE,
        TEMP_CMD_WAIT,
        TEMP_CONVERT_WAIT,
        UT_MSB_ISSUE,
        UT_MSB_WAIT,
        UT_LSB_ISSUE,
        UT_LSB_WAIT,
        PRESS_CMD_ISSUE,
        PRESS_CMD_WAIT,
        PRESS_CONVERT_WAIT,
        P_MSB_ISSUE,
        P_MSB_WAIT,
        P_LSB_ISSUE,
        P_LSB_WAIT,
        P_XLSB_ISSUE,
        P_XLSB_WAIT
    } state_t;

    state_t state;

    assign oss = OSS_CFG;

    // Driver I2C: executa uma transacao por vez
    bmp085_driver #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I2C_FREQ_HZ(100_000)
    ) driver (
        .clk(clk),
        .rst(rst),
        .start(driver_start),
        .read_not_write(driver_read_not_write),
        .device_addr(BMP085_ADDR),
        .reg_addr(driver_reg_addr),
        .write_data(driver_write_data),
        .read_data(driver_read_data),
        .busy(driver_busy),
        .done(driver_done),
        .ack_error(driver_ack_error),
        .scl(scl),
        .sda(sda)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= CAL_ISSUE;

            driver_start <= 1'b0;
            driver_read_not_write <= 1'b1;
            driver_reg_addr <= 8'h00;
            driver_write_data <= 8'h00;

            calib_index <= 0;
            calib_valid <= 1'b0;
            measurement_valid <= 1'b0;
            sensor_ready <= 1'b0;
            i2c_error <= 1'b0;

            ac1 <= 0;
            ac2 <= 0;
            ac3 <= 0;
            ac4 <= 0;
            ac5 <= 0;
            ac6 <= 0;
            b1  <= 0;
            b2  <= 0;
            mb  <= 0;
            mc  <= 0;
            md  <= 0;

            ut <= 0;
            up <= 0;
            ut_msb <= 0;
            pressure_msb <= 0;
            pressure_lsb <= 0;
            wait_counter <= 0;

        end else begin
            // Pulsos de um ciclo
            driver_start <= 1'b0;
            calib_valid <= 1'b0;
            measurement_valid <= 1'b0;

            if (driver_done && driver_ack_error)
                i2c_error <= 1'b1;

            case (state)

                // ----------------------------------------
                // 1. Ler os 22 bytes de calibracao (0xAA-0xBF)
                // ----------------------------------------
                CAL_ISSUE: begin
                    driver_reg_addr <= 8'hAA + calib_index;
                    driver_read_not_write <= 1'b1;
                    driver_start <= 1'b1;
                    state <= CAL_WAIT;
                end

                CAL_WAIT: begin
                    if (driver_done) begin
                        if (driver_ack_error) begin
                            state <= CAL_ISSUE;
                        end else begin
                            calib_bytes[calib_index] <= driver_read_data;

                            if (calib_index == 21) begin
                                state <= CAL_PARSE;
                            end else begin
                                calib_index <= calib_index + 1'b1;
                                state <= CAL_ISSUE;
                            end
                        end
                    end
                end

                // Montar os coeficientes de 16 bits.
                // Executado depois que todos os bytes foram armazenados.
                CAL_PARSE: begin
                    ac1 <= $signed({calib_bytes[0],  calib_bytes[1]});
                    ac2 <= $signed({calib_bytes[2],  calib_bytes[3]});
                    ac3 <= $signed({calib_bytes[4],  calib_bytes[5]});
                    ac4 <=         {calib_bytes[6],  calib_bytes[7]};
                    ac5 <=         {calib_bytes[8],  calib_bytes[9]};
                    ac6 <=         {calib_bytes[10], calib_bytes[11]};
                    b1  <= $signed({calib_bytes[12], calib_bytes[13]});
                    b2  <= $signed({calib_bytes[14], calib_bytes[15]});
                    mb  <= $signed({calib_bytes[16], calib_bytes[17]});
                    mc  <= $signed({calib_bytes[18], calib_bytes[19]});
                    md  <= $signed({calib_bytes[20], calib_bytes[21]});

                    calib_valid <= 1'b1;
                    sensor_ready <= 1'b1;
                    state <= TEMP_CMD_ISSUE;
                end

                // ----------------------------------------
                // 2. Solicitar conversao de temperatura
                // Registrador 0xF4, comando 0x2E
                // ----------------------------------------
                TEMP_CMD_ISSUE: begin
                    driver_reg_addr <= 8'hF4;
                    driver_write_data <= 8'h2E;
                    driver_read_not_write <= 1'b0;
                    driver_start <= 1'b1;
                    state <= TEMP_CMD_WAIT;
                end

                TEMP_CMD_WAIT: begin
                    if (driver_done) begin
                        if (driver_ack_error) begin
                            state <= TEMP_CMD_ISSUE;
                        end else begin
                            wait_counter <= 0;
                            state <= TEMP_CONVERT_WAIT;
                        end
                    end
                end

                TEMP_CONVERT_WAIT: begin
                    if (wait_counter >= WAIT_CYCLES - 1) begin
                        state <= UT_MSB_ISSUE;
                    end else begin
                        wait_counter <= wait_counter + 1'b1;
                    end
                end

                // Ler UT: registradores 0xF6 e 0xF7
                UT_MSB_ISSUE: begin
                    driver_reg_addr <= 8'hF6;
                    driver_read_not_write <= 1'b1;
                    driver_start <= 1'b1;
                    state <= UT_MSB_WAIT;
                end

                UT_MSB_WAIT: begin
                    if (driver_done) begin
                        if (driver_ack_error) begin
                            state <= UT_MSB_ISSUE;
                        end else begin
                            ut_msb <= driver_read_data;
                            state <= UT_LSB_ISSUE;
                        end
                    end
                end

                UT_LSB_ISSUE: begin
                    driver_reg_addr <= 8'hF7;
                    driver_read_not_write <= 1'b1;
                    driver_start <= 1'b1;
                    state <= UT_LSB_WAIT;
                end

                UT_LSB_WAIT: begin
                    if (driver_done) begin
                        if (driver_ack_error) begin
                            state <= UT_LSB_ISSUE;
                        end else begin
                            ut <= {ut_msb, driver_read_data};
                            state <= PRESS_CMD_ISSUE;
                        end
                    end
                end

                // ----------------------------------------
                // 3. Solicitar conversao de pressao
                // Registrador 0xF4
                // ----------------------------------------
                PRESS_CMD_ISSUE: begin
                    driver_reg_addr <= 8'hF4;
                    driver_write_data <= 8'h34 + (OSS_CFG << 6);
                    driver_read_not_write <= 1'b0;
                    driver_start <= 1'b1;
                    state <= PRESS_CMD_WAIT;
                end

                PRESS_CMD_WAIT: begin
                    if (driver_done) begin
                        if (driver_ack_error) begin
                            state <= PRESS_CMD_ISSUE;
                        end else begin
                            wait_counter <= 0;
                            state <= PRESS_CONVERT_WAIT;
                        end
                    end
                end

                PRESS_CONVERT_WAIT: begin
                    if (wait_counter >= WAIT_CYCLES - 1) begin
                        state <= P_MSB_ISSUE;
                    end else begin
                        wait_counter <= wait_counter + 1'b1;
                    end
                end

                // Ler pressao: 0xF6, 0xF7 e 0xF8
                P_MSB_ISSUE: begin
                    driver_reg_addr <= 8'hF6;
                    driver_read_not_write <= 1'b1;
                    driver_start <= 1'b1;
                    state <= P_MSB_WAIT;
                end

                P_MSB_WAIT: begin
                    if (driver_done) begin
                        if (driver_ack_error) begin
                            state <= P_MSB_ISSUE;
                        end else begin
                            pressure_msb <= driver_read_data;
                            state <= P_LSB_ISSUE;
                        end
                    end
                end

                P_LSB_ISSUE: begin
                    driver_reg_addr <= 8'hF7;
                    driver_read_not_write <= 1'b1;
                    driver_start <= 1'b1;
                    state <= P_LSB_WAIT;
                end

                P_LSB_WAIT: begin
                    if (driver_done) begin
                        if (driver_ack_error) begin
                            state <= P_LSB_ISSUE;
                        end else begin
                            pressure_lsb <= driver_read_data;
                            state <= P_XLSB_ISSUE;
                        end
                    end
                end

                P_XLSB_ISSUE: begin
                    driver_reg_addr <= 8'hF8;
                    driver_read_not_write <= 1'b1;
                    driver_start <= 1'b1;
                    state <= P_XLSB_WAIT;
                end

                P_XLSB_WAIT: begin
                    if (driver_done) begin
                        if (driver_ack_error) begin
                            state <= P_XLSB_ISSUE;
                        end else begin
                            // UP = (MSB:LSB:XLSB) >> (8 - OSS)
                            up <= ({pressure_msb, pressure_lsb,
                                    driver_read_data} >> (8 - OSS_CFG));

                            measurement_valid <= 1'b1;
                            state <= TEMP_CMD_ISSUE;
                        end
                    end
                end

                default: begin
                    state <= CAL_ISSUE;
                end

            endcase
        end
    end

endmodule