// =========================================================
// vga_controller.v
// Gera sincronismo VGA 640x480 @ 60Hz
// Clock de pixel necessário: 25 MHz
// Nexys A7 tem clock de 100 MHz -> dividimos por 4
// =========================================================

module vga_controller(
    input  wire       clk_100mhz,   // clock de entrada do board (100 MHz)
    output wire        pixel_clk,    // clock de pixel (25 MHz) - útil se precisar em outro módulo
    output reg          hsync,
    output reg          vsync,
    output wire [9:0]  pixel_x,      // coluna atual (0 a 799, só 0..639 é visível)
    output wire [9:0]  pixel_y,      // linha atual  (0 a 524, só 0..479 é visível)
    output wire         video_on     // '1' quando dentro da área visível 640x480
);

    // ---------------------------------------------------
    // 1) Gerar clock de pixel de 25 MHz a partir de 100 MHz
    //    (divisor simples por 4 -- suficiente para a maioria
    //     dos laboratórios; se precisar de clock mais limpo,
    //     use o Clocking Wizard do Vivado em vez disso)
    // ---------------------------------------------------
    // TODO: Revisar a geração de clk25 e suas constraints de timing no Vivado.
    reg [1:0] div_cnt = 0;
    reg       clk25    = 0;

    always @(posedge clk_100mhz) begin
        div_cnt <= div_cnt + 1;
        if (div_cnt == 2'd1) begin
            clk25    <= ~clk25;
            div_cnt  <= 0;
        end
    end

    assign pixel_clk = clk25;

    // ---------------------------------------------------
    // 2) Parâmetros de temporização 640x480@60Hz
    // ---------------------------------------------------
    // Resolução fixa em 640x480; não há autodetecção nesta versão.
    // A ligação VGA atual não disponibiliza DDC/EDID para consultar o monitor.
    localparam H_VISIVEL     = 640;
    localparam H_FRENTE      = 16;
    localparam H_SYNC        = 96;
    localparam H_TRAS        = 48;
    localparam H_TOTAL       = H_VISIVEL + H_FRENTE + H_SYNC + H_TRAS; // 800

    localparam V_VISIVEL     = 480;
    localparam V_FRENTE      = 10;
    localparam V_SYNC        = 2;
    localparam V_TRAS        = 33;
    localparam V_TOTAL       = V_VISIVEL + V_FRENTE + V_SYNC + V_TRAS; // 525

    reg [9:0] h_cont = 0;
    reg [9:0] v_cont = 0;

    always @(posedge clk25) begin
        if (h_cont == H_TOTAL - 1) begin
            h_cont <= 0;
            if (v_cont == V_TOTAL - 1)
                v_cont <= 0;
            else
                v_cont <= v_cont + 1;
        end else begin
            h_cont <= h_cont + 1;
        end
    end

    // TODO: Alinhar hsync/vsync com pixel_x, pixel_y e video_on; hoje ficam um pixel atrasados.
    // TODO: Adicionar testbench ao projeto para conferir um quadro completo e esse alinhamento.
    // Sincronismos são ativos em nível baixo nesse padrão de timing
    always @(posedge clk25) begin
        hsync <= ~((h_cont >= (H_VISIVEL + H_FRENTE)) &&
                    (h_cont <  (H_VISIVEL + H_FRENTE + H_SYNC)));
        vsync <= ~((v_cont >= (V_VISIVEL + V_FRENTE)) &&
                    (v_cont <  (V_VISIVEL + V_FRENTE + V_SYNC)));
    end

    assign pixel_x  = h_cont;
    assign pixel_y  = v_cont;
    assign video_on = (h_cont < H_VISIVEL) && (v_cont < V_VISIVEL);

endmodule
