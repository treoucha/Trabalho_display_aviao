// Interpreta leituras de 12 bits vindas do XADC.
// Centro e zona morta ficam parametrizados para calibracao posterior.

module controle_joystick #(
    parameter int unsigned CENTRO_X = 1126,
    parameter int unsigned CENTRO_Y = 1126,
    parameter int unsigned DEADZONE = 120
)(
    input  logic [11:0] x_raw,
    input  logic [11:0] y_raw,
    input  logic        sw_n,

    output logic x_menos,
    output logic x_mais,
    output logic y_menos,
    output logic y_mais,
    output logic botao
);

    localparam int unsigned X_MIN =
        (CENTRO_X > DEADZONE) ? CENTRO_X - DEADZONE : 0;

    localparam int unsigned X_MAX =
        ((CENTRO_X + DEADZONE) < 4095) ? CENTRO_X + DEADZONE : 4095;

    localparam int unsigned Y_MIN =
        (CENTRO_Y > DEADZONE) ? CENTRO_Y - DEADZONE : 0;

    localparam int unsigned Y_MAX =
        ((CENTRO_Y + DEADZONE) < 4095) ? CENTRO_Y + DEADZONE : 4095;

    always_comb begin
        x_menos = (x_raw < X_MIN);
        x_mais  = (x_raw > X_MAX);
        y_menos = (y_raw < Y_MIN);
        y_mais  = (y_raw > Y_MAX);
        botao   = ~sw_n;
    end

endmodule
