// Interpreta os dois eixos analogicos do joystick.
//
// O centro e calibrado automaticamente nos primeiros instantes
// apos a FPGA ser programada. Durante a calibracao, manter o
// joystick solto.
//
// Depois da calibracao, uma zona morta evita movimentos causados
// por pequenas variacoes mecanicas/eletricas do joystick.

module controle_joystick #(
    parameter int unsigned DEADZONE = 180,
    parameter int unsigned CALIB_BITS = 25
)(
    input  logic        clk,
    input  logic [11:0] x_raw,
    input  logic [11:0] y_raw,
    input  logic        sw_n,

    output logic x_menos,
    output logic x_mais,
    output logic y_menos,
    output logic y_mais,
    output logic botao
);

    logic [11:0] centro_x = 12'd2048;
    logic [11:0] centro_y = 12'd2048;

    logic [CALIB_BITS-1:0] calib_count = '0;
    logic calibrado = 1'b0;

    // Durante o inicio, acompanha o valor atual do joystick.
    // Quando o contador termina, congela os valores como centro.
    always_ff @(posedge clk) begin
        if (!calibrado) begin
            centro_x <= x_raw;
            centro_y <= y_raw;

            calib_count <= calib_count + 1'b1;

            if (&calib_count)
                calibrado <= 1'b1;
        end
    end

    always_comb begin
        x_menos = 1'b0;
        x_mais  = 1'b0;
        y_menos = 1'b0;
        y_mais  = 1'b0;

        if (calibrado) begin
            if ({1'b0, x_raw} + DEADZONE < {1'b0, centro_x})
                x_menos = 1'b1;
            else if ({1'b0, x_raw} > ({1'b0, centro_x} + DEADZONE))
                x_mais = 1'b1;

            if ({1'b0, y_raw} + DEADZONE < {1'b0, centro_y})
                y_menos = 1'b1;
            else if ({1'b0, y_raw} > ({1'b0, centro_y} + DEADZONE))
                y_mais = 1'b1;
        end

        botao = ~sw_n;
    end

endmodule
