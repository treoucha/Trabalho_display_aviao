`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/18/2026 09:04:24 AM
// Design Name: 
// Module Name: vga_top
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


module vga_top(
    input clk,
    output vga_hsync,
    output vga_vsync,
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b
);

    vga_controller controller(
        .clk(clk),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .red(vga_r),
        .green(vga_g),
        .blue(vga_b)
    );

endmodule
