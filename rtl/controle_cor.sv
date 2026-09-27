// Controles do retículo no domínio de pixel (25 MHz).
module controle_cor #(
    parameter int DEBOUNCE_CYCLES = 250_000 // 10 ms
)(
    input  logic clk,
    input  logic [2:0] btn_rgb,
    input  logic [11:0] sw,
    input  logic atualizar,
    output logic [11:0] rgb = 12'h0F0
);
    localparam int COUNT_WIDTH = (DEBOUNCE_CYCLES > 1) ? $clog2(DEBOUNCE_CYCLES) : 1;
    (* ASYNC_REG = "TRUE" *) logic [2:0] btn_meta = '0, btn_sync = '0;
    (* ASYNC_REG = "TRUE" *) logic [11:0] sw_meta = '0, sw_sync = '0;
    logic [2:0] estavel = '0;
    logic [2:0] habilitado = 3'b010; // Verde após configuração.

    always_ff @(posedge clk) begin
        btn_meta <= btn_rgb;
        btn_sync <= btn_meta;
        sw_meta <= sw;
        sw_sync <= sw_meta;
        // A cor fica constante durante a área visível do quadro.
        if (atualizar) begin
            rgb[3:0]  <= habilitado[0] ? sw_sync[3:0]  : 4'h0;
            rgb[7:4]  <= habilitado[1] ? sw_sync[7:4]  : 4'h0;
            rgb[11:8] <= habilitado[2] ? sw_sync[11:8] : 4'h0;
        end
    end

    for (genvar canal = 0; canal < 3; canal++) begin : g_botao
        logic [COUNT_WIDTH-1:0] contador = '0;
        always_ff @(posedge clk) begin
            if (btn_sync[canal] == estavel[canal]) begin
                contador <= '0;
            end else if (contador == COUNT_WIDTH'(DEBOUNCE_CYCLES - 1)) begin
                contador <= '0;
                estavel[canal] <= btn_sync[canal];
                // Alterna uma vez por pressão; soltar apenas rearma o botão.
                if (btn_sync[canal])
                    habilitado[canal] <= ~habilitado[canal];
            end else begin
                contador <= contador + 1'b1;
            end
        end
    end
endmodule
