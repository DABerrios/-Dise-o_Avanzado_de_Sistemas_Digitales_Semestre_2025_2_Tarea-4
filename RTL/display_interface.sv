`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/06/2026 11:49:47 AM
// Design Name: 
// Module Name: display_interface
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


module display_interface (
    input logic clk,
    input logic reset,
    
    // Data Input
    input logic [47:0] data_in,
    input logic [1:0]  opcode,
    
    // Hardware Pins 
    output logic [7:0] an,          // Anodes 
    output logic [6:0] seg,         // Segments 
    output logic       dp           // Decimal Point
);

    logic refresh_tick;
    pulse_generator #(.COUNTER_MAX(100_000)) refresh_gen_inst (
        .clk_in(clk), .reset(reset), .pulse_out(refresh_tick)
    );


    localparam int TOGGLE_MAX = 300_000_000;
    logic [28:0] view_timer;
    logic        view_state; 

    always_ff @(posedge clk) begin
        if (reset) begin
            view_timer <= '0;
            view_state <= 1'b0;
        end else begin
            if (view_timer == TOGGLE_MAX - 1) begin
                view_timer <= '0;
                view_state <= ~view_state;
            end else begin
                view_timer <= view_timer + 1'b1;
            end
        end
    end


    logic [2:0] digit_sel;
    always_ff @(posedge clk) begin
        if (reset) digit_sel <= 0;
        else if (refresh_tick) digit_sel <= digit_sel + 1;
    end

    logic [31:0] display_value;
    logic        decimal_point_en;

    always_comb begin
        decimal_point_en = 0; 
        if (opcode == 0) begin
            display_value = data_in[47:16]; 
        end else begin
            if (view_state == 0) begin
                display_value = data_in[47:16];
                if (digit_sel == 0) decimal_point_en = 1; 
            end else begin
                display_value = {16'h0000, data_in[15:0]}; 
                if (digit_sel == 4) decimal_point_en = 1;
            end
        end
    end

    logic [3:0] nibble;
    always_comb begin
        case (digit_sel)
            3'd0: nibble = display_value[3:0];   
            3'd1: nibble = display_value[7:4];
            3'd2: nibble = display_value[11:8];
            3'd3: nibble = display_value[15:12];
            3'd4: nibble = display_value[19:16];
            3'd5: nibble = display_value[23:20];
            3'd6: nibble = display_value[27:24];
            3'd7: nibble = display_value[31:28];
        endcase
    end


    always_comb begin
        case (nibble)
            //                  gfedcba 
            4'h0: seg = 7'b1000000; // 0
            4'h1: seg = 7'b1111001; // 1
            4'h2: seg = 7'b0100100; // 2
            4'h3: seg = 7'b0110000; // 3
            4'h4: seg = 7'b0011001; // 4
            4'h5: seg = 7'b0010010; // 5
            4'h6: seg = 7'b0000010; // 6
            4'h7: seg = 7'b1111000; // 7
            4'h8: seg = 7'b0000000; // 8
            4'h9: seg = 7'b0010000; // 9
            4'hA: seg = 7'b0001000; // A
            4'hB: seg = 7'b0000011; // b
            4'hC: seg = 7'b1000110; // C
            4'hD: seg = 7'b0100001; // d
            4'hE: seg = 7'b0000110; // E
            4'hF: seg = 7'b0001110; // F
            default: seg = 7'b1111111; 
        endcase
    end

    always_comb begin
        an = 8'hFF; 
        an[digit_sel] = 0; 
    end
    
    assign dp = ~decimal_point_en; 

endmodule