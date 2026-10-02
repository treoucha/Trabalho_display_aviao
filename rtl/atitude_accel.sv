// =========================================================
// atitude_accel.sv
//
// Converte os eixos descobertos pela calibracao automatica
// em comandos simples de pitch e roll para o HUD.
//
// Primeira versao intencionalmente simples:
// - ponto fixo
// - sem atan
// - sem sqrt
// - sem filtro complementar
//
// O giroscopio sera usado depois para refinamento.
// =========================================================

module atitude_accel (
    input logic calibrado,

    input logic signed [15:0] accel_x,
    input logic signed [15:0] accel_y,
    input logic signed [15:0] accel_z,

    input logic signed [15:0] referencia_x,
    input logic signed [15:0] referencia_y,
    input logic signed [15:0] referencia_z,

    input logic [1:0] eixo_pitch,
    input logic [1:0] eixo_roll,

    input logic inverte_pitch,
    input logic inverte_roll,

    output logic signed [10:0] pitch_px,
    output logic signed [9:0]  roll_q8
);

    logic signed [16:0] dx;
    logic signed [16:0] dy;
    logic signed [16:0] dz;

    logic signed [16:0] delta_pitch;
    logic signed [16:0] delta_roll;

    logic signed [17:0] pitch_dir;
    logic signed [17:0] roll_dir;

    logic signed [17:0] pitch_scaled;
    logic signed [17:0] roll_scaled;

    always_comb begin

        dx = $signed({accel_x[15], accel_x})
           - $signed({referencia_x[15], referencia_x});

        dy = $signed({accel_y[15], accel_y})
           - $signed({referencia_y[15], referencia_y});

        dz = $signed({accel_z[15], accel_z})
           - $signed({referencia_z[15], referencia_z});

        case (eixo_pitch)
            2'd0: delta_pitch = dx;
            2'd1: delta_pitch = dy;
            default: delta_pitch = dz;
        endcase

        case (eixo_roll)
            2'd0: delta_roll = dx;
            2'd1: delta_roll = dy;
            default: delta_roll = dz;
        endcase

        if (inverte_pitch)
            pitch_dir = -$signed({delta_pitch[16], delta_pitch});
        else
            pitch_dir =  $signed({delta_pitch[16], delta_pitch});

        if (inverte_roll)
            roll_dir = -$signed({delta_roll[16], delta_roll});
        else
            roll_dir =  $signed({delta_roll[16], delta_roll});

        // Aproximacao inicial:
        // ~8192 counts produz cerca de 64 px de pitch.
        // ~8192 counts produz cerca de 128 unidades de roll.
        pitch_scaled = pitch_dir >>> 7;
        roll_scaled  = roll_dir  >>> 6;

        pitch_px = 11'sd0;
        roll_q8  = 10'sd0;

        if (calibrado) begin

            // Pequena zona morta para evitar tremor parado.
            if ((pitch_scaled > -18'sd3) &&
                (pitch_scaled <  18'sd3))
                pitch_px = 11'sd0;
            else if (pitch_scaled > 18'sd80)
                pitch_px = 11'sd80;
            else if (pitch_scaled < -18'sd80)
                pitch_px = -11'sd80;
            else
                pitch_px = pitch_scaled[10:0];

            if ((roll_scaled > -18'sd5) &&
                (roll_scaled <  18'sd5))
                roll_q8 = 10'sd0;
            else if (roll_scaled > 18'sd128)
                roll_q8 = 10'sd128;
            else if (roll_scaled < -18'sd128)
                roll_q8 = -10'sd128;
            else
                roll_q8 = roll_scaled[9:0];

        end
    end

endmodule
