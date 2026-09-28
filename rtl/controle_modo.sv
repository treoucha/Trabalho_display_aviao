// Switch filtrado a 25 MHz; o modo visível muda entre quadros.
module controle_modo #(
    parameter int DEBOUNCE_CYCLES = 250_000
)(
    input logic clk,
    input logic display_mode,
    input logic atualizar,
    output logic declutter = 1'b0
);
    localparam int WIDTH = (DEBOUNCE_CYCLES > 1) ? $clog2(DEBOUNCE_CYCLES) : 1;
    (* ASYNC_REG = "TRUE" *) logic modo_meta = 1'b0;
    (* ASYNC_REG = "TRUE" *) logic modo_sync = 1'b0;
    logic estavel = 1'b0;
    logic [WIDTH-1:0] contador = '0;

    always_ff @(posedge clk) begin
        modo_meta <= display_mode;
        modo_sync <= modo_meta;
        if (modo_sync == estavel)
            contador <= '0;
        else if (contador == WIDTH'(DEBOUNCE_CYCLES - 1)) begin
            contador <= '0;
            estavel <= modo_sync;
        end else
            contador <= contador + 1'b1;

        // O quadro inteiro usa o mesmo modo.
        if (atualizar)
            declutter <= estavel;
    end
endmodule
