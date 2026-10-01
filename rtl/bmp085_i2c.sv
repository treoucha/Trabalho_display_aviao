
module bmp085_i2c (
    input  logic               clk,
    input  logic               rst,

    // Coeficientes de calibracao do BMP085
    input  logic               calib_valid,
    input  logic signed [15:0] ac1,
    input  logic signed [15:0] ac2,
    input  logic signed [15:0] ac3,
    input  logic        [15:0] ac4,
    input  logic        [15:0] ac5,
    input  logic        [15:0] ac6,
    input  logic signed [15:0] b1,
    input  logic signed [15:0] b2,
    input  logic signed [15:0] mb,
    input  logic signed [15:0] mc,
    input  logic signed [15:0] md,

    // Leituras brutas obtidas por I2C
    input  logic               measurement_valid,
    input  logic        [15:0] ut,
    input  logic        [19:0] up,
    input  logic        [1:0]  oss,

    // Resultados compensados
    output logic               result_valid,
    output logic signed [15:0] temperature_tenths_c,
    output logic        [31:0] pressure_pa,
    output logic               sensor_ready
);

    logic signed [31:0] x1, x2, x3;
    logic signed [31:0] b5, b6;
    logic signed [31:0] b3;
    logic        [31:0] b4;
    logic        [31:0] b7;
    logic signed [31:0] p;
    logic signed [63:0] temp_a;
    logic signed [63:0] temp_b;
    logic signed [63:0] temp_c;

    logic signed [31:0] calc_x1;
    logic signed [31:0] calc_x2;
    logic signed [31:0] calc_x3;
    logic signed [31:0] calc_b5;
    logic signed [31:0] calc_b6;
    logic signed [31:0] calc_b3;
    logic        [31:0] calc_b4;
    logic        [31:0] calc_b7;
    logic signed [31:0] calc_p;
    logic signed [15:0] calc_temp;

    always_comb begin
        // Valores padrao
        calc_x1   = 0;
        calc_x2   = 0;
        calc_x3   = 0;
        calc_b5   = 0;
        calc_b6   = 0;
        calc_b3   = 0;
        calc_b4   = 0;
        calc_b7   = 0;
        calc_p    = 0;
        calc_temp = 0;

        temp_a = 0;
        temp_b = 0;
        temp_c = 0;

        // Compensacao de temperatura
        temp_a = ($signed({1'b0, ut}) - ac6) * ac5;
        calc_x1 = temp_a >>> 15;

        if ((calc_x1 + md) != 0) begin
            temp_b = $signed(mc) <<< 11;
            calc_x2 = temp_b / (calc_x1 + md);
        end

        calc_b5 = calc_x1 + calc_x2;
        calc_temp = (calc_b5 + 8) >>> 4;

        // Compensacao de pressao
        calc_b6 = calc_b5 - 4000;

        temp_a = ($signed(b2) *
                 (($signed(calc_b6) * calc_b6) >>> 12));
        calc_x1 = temp_a >>> 11;

        temp_b = $signed(ac2) * calc_b6;
        calc_x2 = temp_b >>> 11;

        calc_x3 = calc_x1 + calc_x2;

        temp_c = (($signed(ac1) * 4 + calc_x3) *
                  (1 <<< oss)) + 2;
        calc_b3 = temp_c >>> 2;

        temp_a = $signed(ac3) * calc_b6;
        calc_x1 = temp_a >>> 13;

        temp_b = $signed(b1) *
                 (($signed(calc_b6) * calc_b6) >>> 12);
        calc_x2 = temp_b >>> 16;

        calc_x3 = (calc_x1 + calc_x2 + 2) >>> 2;

        temp_a = $signed({1'b0, ac4}) *
                 (calc_x3 + 32768);
        calc_b4 = temp_a >>> 15;

        calc_b7 = 0;
        calc_p = 0;

        if (calc_b4 != 0 && up > calc_b3) begin
            calc_b7 = (up - calc_b3) * (50000 >> oss);

            if (calc_b7 < 32'h80000000)
                calc_p = (calc_b7 * 2) / calc_b4;
            else
                calc_p = (calc_b7 / calc_b4) * 2;

            temp_a = (calc_p >>> 8) * (calc_p >>> 8);
            temp_b = (temp_a * 3038) >>> 16;
            temp_c = (-7357 * calc_p) >>> 16;

            calc_p = calc_p + ((temp_b + temp_c + 3791) >>> 4);
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            result_valid       <= 1'b0;
            temperature_tenths_c <= 0;
            pressure_pa        <= 0;
            sensor_ready       <= 1'b0;
        end else begin
            result_valid <= 1'b0;

            if (calib_valid)
                sensor_ready <= 1'b1;

            if (measurement_valid && sensor_ready) begin
                temperature_tenths_c <= calc_temp;

                if (calc_p > 0)
                    pressure_pa <= calc_p;

                result_valid <= (calc_p > 0);
            end
        end
    end

endmodule