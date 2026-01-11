`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/06/2026 11:48:12 AM
// Design Name: 
// Module Name: control_out
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


module control_out (
    input logic clk,
    input logic reset,

    // --- Interface to HLS Core ---
    input logic        ap_done,
    input logic [47:0] hls_result,
    input logic [1:0]  hls_opcode,

    // --- Interface to UART TX ---
    input logic        tx_busy,
    output logic        tx_start,
    output logic [7:0]  tx_data,

    // --- Interface to Display Module ---
    output logic [47:0] disp_data,
    output logic [1:0]  disp_opcode
);

    typedef enum logic [2:0] {
        IDLE,
        CAPTURE,    
        WAIT_TX,    
        PULSE_TX,   
        SHIFT       
    } state_t;

    state_t state;
    logic [2:0]  byte_cnt;
    logic [47:0] shift_reg;

    always_comb begin
        tx_start = 0;
        tx_data  = shift_reg[7:0]; 

        case (state)
            PULSE_TX: tx_start = 1; 
            default:  tx_start = 0;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            state       <= IDLE;
            disp_data   <= 0;
            disp_opcode <= 0;
            byte_cnt    <= 0;
            shift_reg   <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (ap_done) begin
                        state <= CAPTURE;
                    end
                end

                CAPTURE: begin
                    disp_data   <= hls_result;
                    disp_opcode <= hls_opcode;
                    
                    shift_reg   <= hls_result;
                    byte_cnt    <= 0;
                    
                    state       <= WAIT_TX;
                end

                WAIT_TX: begin
                    if (!tx_busy) begin
                        state <= PULSE_TX;
                    end
                end

                PULSE_TX: begin
                    state <= SHIFT;
                end

                SHIFT: begin
                    shift_reg <= {8'h00, shift_reg[47:8]};

                    if (byte_cnt == 5) begin
                        state <= IDLE;
                    end else begin
                        byte_cnt <= byte_cnt + 1;
                        state    <= WAIT_TX;
                    end
                end
            endcase
        end
    end

endmodule
