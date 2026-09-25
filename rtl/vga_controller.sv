`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/18/2026 09:04:24 AM
// Design Name: 
// Module Name: vga_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module vga_controller(
    input clk,
    output hsync,
    output vsync,
    output [3:0] red,
    output [3:0] green,
    output [3:0] blue
);

    // Clock da placa = 100 MHz
    // Pixel enable = 25 MHz
    reg [1:0] clock_div = 0;

    always @(posedge clk) begin
        clock_div <= clock_div + 1;
    end

    wire pixel_tick;
    assign pixel_tick = (clock_div == 0);


    // Contadores VGA
    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    always @(posedge clk) begin

        if (pixel_tick) begin

            if (h_count == 799) begin
                h_count <= 0;

                if (v_count == 524)
                    v_count <= 0;
                else
                    v_count <= v_count + 1;

            end
            else begin
                h_count <= h_count + 1;
            end

        end

    end


    // Sincronismo horizontal
    // 640 visível
    // 16 front porch
    // 96 sync
    // 48 back porch

    assign hsync =
        ~((h_count >= 656) &&
          (h_count < 752));


    // Sincronismo vertical
    // 480 visível
    // 10 front porch
    // 2 sync
    // 33 back porch

    assign vsync =
        ~((v_count >= 490) &&
          (v_count < 492));


    // Área visível
    wire visible;

    assign visible =
        (h_count < 640) &&
        (v_count < 480);


    // Tela azul para teste

    assign red =
        visible ? 4'b0000 : 4'b0000;

    assign green =
        visible ? 4'b0000 : 4'b0000;

    assign blue =
        visible ? 4'b1111 : 4'b0000;

endmodule
