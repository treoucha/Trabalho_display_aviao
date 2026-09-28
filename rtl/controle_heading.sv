// Controle manual do rumo para demonstracao do HUD.
// BTNU incrementa 10 graus e BTND decrementa 10 graus.
module controle_heading #(
    parameter int DEBOUNCE_CYCLES = 1_000_000
)(
    input  logic       clk,
    input  logic [1:0] btn, // [0]=BTNU, [1]=BTND
    output logic [8:0] heading_deg = 9'd0
);

    localparam int COUNT_WIDTH =
        (DEBOUNCE_CYCLES > 1) ? $clog2(DEBOUNCE_CYCLES) : 1;

    (* ASYNC_REG = "TRUE" *) logic [1:0] btn_meta = '0;
    (* ASYNC_REG = "TRUE" *) logic [1:0] btn_sync = '0;

    logic [1:0] estavel = '0;
    logic [1:0] pulso = '0;

    always_ff @(posedge clk) begin
        btn_meta <= btn;
        btn_sync <= btn_meta;
    end

    for (genvar botao = 0; botao < 2; botao++) begin : g_debounce
        logic [COUNT_WIDTH-1:0] contador = '0;

        always_ff @(posedge clk) begin
            pulso[botao] <= 1'b0;

            if (btn_sync[botao] == estavel[botao]) begin
                contador <= '0;
            end
            else if (contador == COUNT_WIDTH'(DEBOUNCE_CYCLES - 1)) begin
                contador <= '0;
                estavel[botao] <= btn_sync[botao];

                if (btn_sync[botao])
                    pulso[botao] <= 1'b1;
            end
            else begin
                contador <= contador + 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        // Dois botoes pressionados ao mesmo tempo nao alteram o rumo.
        if (pulso[0] && !pulso[1]) begin
            if (heading_deg >= 9'd350)
                heading_deg <= 9'd0;
            else
                heading_deg <= heading_deg + 9'd10;
        end
        else if (pulso[1] && !pulso[0]) begin
            if (heading_deg < 9'd10)
                heading_deg <= 9'd350;
            else
                heading_deg <= heading_deg - 9'd10;
        end
    end

endmodule
