// Transfere uma amostra completa de 100 MHz para o domínio de pixel.
module entrada_hud (
    input logic clk_origem, clk_destino,
    input logic valido,
    input logic [47:0] dados,
    output wire pronto,
    output logic valido_destino = 1'b0,
    output logic [47:0] dados_destino = '0
);
    // O barramento fica estável desde a requisição até a confirmação.
    logic [47:0] retido = '0;
    logic pedido = 1'b0, confirmado = 1'b0;
    (* ASYNC_REG = "TRUE" *) logic pedido_meta = 0, pedido_sync = 0;
    (* ASYNC_REG = "TRUE" *) logic confirmado_meta = 0, confirmado_sync = 0;
    assign pronto = (pedido == confirmado_sync);
    always_ff @(posedge clk_origem) begin
        confirmado_meta <= confirmado;
        confirmado_sync <= confirmado_meta;
        if (valido && pronto) begin
            retido <= dados;
            pedido <= ~pedido;
        end
    end
    always_ff @(posedge clk_destino) begin
        pedido_meta <= pedido;
        pedido_sync <= pedido_meta;
        valido_destino <= 0;
        if (pedido_sync != confirmado) begin
            dados_destino <= retido;
            valido_destino <= 1;
            confirmado <= pedido_sync;
        end
    end
endmodule
