// =========================================================
// vga_controller.sv
// Gera sincronismo VGA 640x480 @ 60 Hz
// Clock de entrada: 100 MHz
// Clock de pixel: 25 MHz
// =========================================================

module vga_controller (
    input  logic       clk_100mhz,

    output wire        pixel_clk,
    output logic       hsync,
    output logic       vsync,

    output wire [9:0]  pixel_x,
    output wire [9:0]  pixel_y,
    output wire        video_on
);

    // -----------------------------------------------------
    // Clock de pixel: 100 MHz / 4 = 25 MHz
    // -----------------------------------------------------

    logic [1:0] div_cnt = 2'd0;
    logic       clk25   = 1'b0;

    always_ff @(posedge clk_100mhz) begin
        div_cnt <= div_cnt + 1'b1;

        if (div_cnt == 2'd1) begin
            clk25   <= ~clk25;
            div_cnt <= 2'd0;
        end
    end

    assign pixel_clk = clk25;

    // -----------------------------------------------------
    // VGA 640x480 @ 60 Hz
    // -----------------------------------------------------

    localparam int H_VISIVEL = 640;
    localparam int H_FRENTE  = 16;
    localparam int H_SYNC    = 96;
    localparam int H_TRAS    = 48;
    localparam int H_TOTAL   = H_VISIVEL + H_FRENTE + H_SYNC + H_TRAS;

    localparam int V_VISIVEL = 480;
    localparam int V_FRENTE  = 10;
    localparam int V_SYNC    = 2;
    localparam int V_TRAS    = 33;
    localparam int V_TOTAL   = V_VISIVEL + V_FRENTE + V_SYNC + V_TRAS;

    logic [9:0] h_cont = 10'd0;
    logic [9:0] v_cont = 10'd0;

    // -----------------------------------------------------
    // Contadores
    // -----------------------------------------------------

    always_ff @(posedge clk25) begin
        if (h_cont == H_TOTAL - 1) begin
            h_cont <= 10'd0;

            if (v_cont == V_TOTAL - 1)
                v_cont <= 10'd0;
            else
                v_cont <= v_cont + 1'b1;
        end
        else begin
            h_cont <= h_cont + 1'b1;
        end
    end

    // -----------------------------------------------------
    // Sincronismo VGA
    // Ativo em nível baixo
    // -----------------------------------------------------

    always_ff @(posedge clk25) begin
        hsync <= ~(
            (h_cont >= H_VISIVEL + H_FRENTE) &&
            (h_cont <  H_VISIVEL + H_FRENTE + H_SYNC)
        );

        vsync <= ~(
            (v_cont >= V_VISIVEL + V_FRENTE) &&
            (v_cont <  V_VISIVEL + V_FRENTE + V_SYNC)
        );
    end

    assign pixel_x  = h_cont;
    assign pixel_y  = v_cont;

    assign video_on =
        (h_cont < H_VISIVEL) &&
        (v_cont < V_VISIVEL);

endmodule