// Estimativa quase estática: razão entre gravidade em X/Y e Z positivo.
// Calibre parado, próximo do nível. Não faz integração do giroscópio.
module atitude_mpu6050 #(
    parameter integer CAL_LOG2 = 6,
    parameter integer TIMEOUT_CYCLES = 5_000_000
)(
    input logic clk, sensor_ok, amostra_valida,
    input logic signed [15:0] accel_x, accel_y, accel_z,
    input logic signed [15:0] gyro_x, gyro_y, gyro_z,
    output logic calibrado = 0,
    output logic atitude_ok = 0,
    output logic nova_atitude = 0,
    output logic signed [10:0] pitch_px = 0,
    output logic signed [9:0] roll_q8 = 0
);
    typedef enum logic [2:0] {IDLE, DIVIDE, NEXT_AXIS, CALIBRATE, FILTER, PUBLISH} state_t;
    state_t state = IDLE;
    logic [23:0] quotient = 0;
    logic [16:0] remainder = 0;
    logic [15:0] denominator = 1;
    wire [16:0] shifted = {remainder[15:0], quotient[23]};
    logic [4:0] bit_count = 0;
    logic axis_y = 0, negative = 0;
    logic signed [15:0] saved_y = 0;
    logic signed [23:0] ratio_x = 0, ratio_y = 0;
    logic signed [23:0] offset_x = 0, offset_y = 0;
    logic signed [31:0] sum_x = 0, sum_y = 0;
    logic [CAL_LOG2:0] cal_count = 0;
    logic signed [23:0] filtered_x = 0, filtered_y = 0;
    logic signed [15:0] previous_x = 0, previous_y = 0, previous_z = 0;
    logic [31:0] age = 0;
    wire signed [31:0] dx = 32'(accel_x) - 32'(previous_x);
    wire signed [31:0] dy = 32'(accel_y) - 32'(previous_y);
    wire signed [31:0] dz = 32'(accel_z) - 32'(previous_z);
    wire quiet = (gyro_x > -655 && gyro_x < 655) &&
                 (gyro_y > -655 && gyro_y < 655) &&
                 (gyro_z > -655 && gyro_z < 655) &&
                 (accel_x > -4096 && accel_x < 4096) &&
                 (accel_y > -4096 && accel_y < 4096) &&
                 (accel_z > 14000 && accel_z < 18000) &&
                 (cal_count == 0 || (dx > -256 && dx < 256 &&
                  dy > -256 && dy < 256 && dz > -256 && dz < 256));
    // Limita a inclinação de bancada; evita divisão perto de Z=0.
    wire usable = accel_z >= 8192;
    wire signed [31:0] pitch_scaled = (32'(filtered_x) * 5) >>> 7;
    wire signed [23:0] roll_scaled = filtered_y >>> 4;

    function automatic [23:0] magnitude_q8(input logic signed [15:0] value);
        logic signed [16:0] extended;
        begin
            extended = {value[15],value};
            magnitude_q8 = {16'(extended < 0 ? -extended : extended),8'b0};
        end
    endfunction

    always_ff @(posedge clk) begin
        nova_atitude <= 0;
        if (amostra_valida) age <= 0;
        else if (age < TIMEOUT_CYCLES) age <= age + 1'b1;

        if (!sensor_ok || (age >= TIMEOUT_CYCLES && !amostra_valida)) begin
            state <= IDLE;
            calibrado <= 0;
            atitude_ok <= 0;
            cal_count <= 0;
            sum_x <= 0;
            sum_y <= 0;
            // Mantém o último horizonte; a próxima conexão recalibra.
        end else case (state)
            IDLE: if (amostra_valida) begin
                previous_x <= accel_x;
                previous_y <= accel_y;
                previous_z <= accel_z;
                if (!usable || (!calibrado && !quiet)) begin
                    atitude_ok <= 0;
                    if (!calibrado) begin
                        cal_count <= 0;
                        sum_x <= 0;
                        sum_y <= 0;
                    end
                end else begin
                    quotient <= magnitude_q8(accel_x);
                    remainder <= 0;
                    denominator <= 16'(accel_z);
                    negative <= accel_x < 0;
                    saved_y <= accel_y;
                    axis_y <= 0;
                    bit_count <= 23;
                    state <= DIVIDE;
                end
            end
            DIVIDE: begin
                // Divisão restauradora: um bit por ciclo, sem divisor combinacional.
                if (shifted >= {1'b0,denominator}) begin
                    remainder <= shifted - {1'b0,denominator};
                    quotient <= {quotient[22:0],1'b1};
                end else begin
                    remainder <= shifted;
                    quotient <= {quotient[22:0],1'b0};
                end
                if (bit_count == 0) state <= NEXT_AXIS;
                else bit_count <= bit_count - 1'b1;
            end
            NEXT_AXIS: if (!axis_y) begin
                ratio_x <= negative ? -$signed(quotient) : $signed(quotient);
                quotient <= magnitude_q8(saved_y);
                remainder <= 0;
                negative <= saved_y < 0;
                axis_y <= 1;
                bit_count <= 23;
                state <= DIVIDE;
            end else begin
                ratio_y <= negative ? -$signed(quotient) : $signed(quotient);
                state <= calibrado ? FILTER : CALIBRATE;
            end
            CALIBRATE: begin
                if (cal_count == (1 << CAL_LOG2)-1) begin
                    offset_x <= 24'((sum_x + 32'(ratio_x)) >>> CAL_LOG2);
                    offset_y <= 24'((sum_y + 32'(ratio_y)) >>> CAL_LOG2);
                    filtered_x <= 0;
                    filtered_y <= 0;
                    calibrado <= 1;
                    state <= PUBLISH;
                end else begin
                    sum_x <= sum_x + 32'(ratio_x);
                    sum_y <= sum_y + 32'(ratio_y);
                    cal_count <= cal_count + 1'b1;
                    state <= IDLE;
                end
            end
            FILTER: begin
                // Q4 adicional conserva a fração do filtro exponencial de 1/4.
                filtered_x <= filtered_x + ((((ratio_x-offset_x) <<< 4)-filtered_x) >>> 2);
                filtered_y <= filtered_y + ((((ratio_y-offset_y) <<< 4)-filtered_y) >>> 2);
                state <= PUBLISH;
            end
            PUBLISH: begin
                pitch_px <= (pitch_scaled > 80) ? 11'sd80 :
                            (pitch_scaled < -80) ? -11'sd80 : 11'(pitch_scaled);
                roll_q8 <= (roll_scaled > 128) ? 10'sd128 :
                           (roll_scaled < -128) ? -10'sd128 : 10'(roll_scaled);
                nova_atitude <= 1;
                atitude_ok <= 1;
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
endmodule
