// =========================================================
// filtro_accel.sv
//
// Filtro passa-baixa IIR simples para o acelerometro.
//
// y[n] = y[n-1] + (x[n] - y[n-1]) / 4
//
// SHIFT = 2 -> divisao por 4.
//
// Atualiza apenas quando chega um conjunto completo
// de AX/AY/AZ.
// =========================================================

module filtro_accel #(
    parameter int SHIFT = 2
)(
    input logic clk,
    input logic amostra_nova,

    input logic signed [15:0] x_in,
    input logic signed [15:0] y_in,
    input logic signed [15:0] z_in,

    output logic signed [15:0] x_out = 16'sd0,
    output logic signed [15:0] y_out = 16'sd0,
    output logic signed [15:0] z_out = 16'sd0
);

    logic amostra_anterior = 1'b0;
    logic inicializado = 1'b0;

    logic signed [16:0] dx;
    logic signed [16:0] dy;
    logic signed [16:0] dz;

    always_comb begin
        dx = $signed({x_in[15], x_in})
           - $signed({x_out[15], x_out});

        dy = $signed({y_in[15], y_in})
           - $signed({y_out[15], y_out});

        dz = $signed({z_in[15], z_in})
           - $signed({z_out[15], z_out});
    end

    always_ff @(posedge clk) begin

        amostra_anterior <= amostra_nova;

        // Detecta somente a subida do sinal.
        if (amostra_nova && !amostra_anterior) begin

            if (!inicializado) begin
                x_out <= x_in;
                y_out <= y_in;
                z_out <= z_in;

                inicializado <= 1'b1;
            end
            else begin
                x_out <= $signed(x_out)
                       + $signed(dx >>> SHIFT);

                y_out <= $signed(y_out)
                       + $signed(dy >>> SHIFT);

                z_out <= $signed(z_out)
                       + $signed(dz >>> SHIFT);
            end
        end
    end

endmodule
