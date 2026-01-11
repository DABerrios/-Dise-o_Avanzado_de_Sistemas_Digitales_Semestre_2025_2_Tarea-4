`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/01/2025 12:58:45 PM
// Design Name: 
// Module Name: pulse_generator
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

module pulse_generator #(
    parameter int COUNTER_MAX = 100_000
)(
    input  logic clk_in,
    input  logic reset,
    output logic pulse_out
);

    localparam int COUNTER_WIDTH = $clog2(COUNTER_MAX);
    logic [COUNTER_WIDTH-1:0] counter;

    always_ff @(posedge clk_in or posedge reset) begin
        if (reset) begin
            counter <= '0;
            pulse_out <= 1'b0;
        end
        else begin
            pulse_out <= 1'b0;
            if (counter == COUNTER_MAX - 1) begin
                counter <= '0;
                pulse_out <= 1'b1;
            end
            else begin
                counter <= counter + 1'b1;
            end
        end
    end

endmodule