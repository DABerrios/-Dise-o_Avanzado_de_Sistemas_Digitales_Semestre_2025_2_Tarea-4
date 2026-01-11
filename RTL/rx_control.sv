`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/06/2026 10:32:08 AM
// Design Name: 
// Module Name: rx_control
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


module rx_control (
    input logic clk,
    input logic reset,

    // --- UART RX Interface ---
    input logic [7:0] rx_data,
    input logic       rx_ready,

    // --- HLS Control Interface ---
    input logic        ap_done,
    output logic        ap_start,
    output logic [1:0]  hls_opcode,

    // --- Memory Write Interface ---
    output logic       we_vec_1,    
    output logic       we_vec_2,    
    output logic [9:0] mem_waddr,
    output logic [9:0] mem_wdata
);

typedef enum logic [3:0] {
        IDLE, 
        BANK_DEC, 
        GET_LO, 
        GET_HI, 
        DO_WRITE,  
        INC_ADDR,  
        CMD_DEC, 
        DO_START,  
        WAIT_HLS
    } state_t;

    state_t state;
    logic [7:0]  temp_lo;      

   always_comb begin
        ap_start = 0;
        we_vec_1 = 0;
        we_vec_2 = 0;

        case (state)
            DO_WRITE: begin
                if (hls_opcode[1] == 0) we_vec_1 = 1;
                else                    we_vec_2 = 1;
            end

            DO_START: begin
                ap_start = 1;
            end
            
            default: ; 
        endcase
    end

    // ----------------------------------------------------------------
    // 2. SEQUENTIAL LOGIC (Datapath & State Transitions)
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            state      <= IDLE;
            mem_waddr  <= 0;
            hls_opcode <= 0;
            mem_wdata  <= 0;
            temp_lo    <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (rx_ready) begin
                        if (rx_data == "W")      state <= BANK_DEC;
                        else if (rx_data == "C") state <= CMD_DEC;
                    end
                end

                BANK_DEC: begin
                    if (rx_ready) begin
                        if (rx_data == "A") hls_opcode[1] <= 0; 
                        if (rx_data == "B") hls_opcode[1] <= 1;
                        mem_waddr <= 0; 
                        state <= GET_LO;
                    end
                end

                GET_LO: begin
                    if (rx_ready) begin
                        temp_lo <= rx_data;
                        state <= GET_HI;
                    end
                end

                GET_HI: begin
                    if (rx_ready) begin
                        mem_wdata <= {rx_data[1:0], temp_lo}; 
                        state <= DO_WRITE;
                    end
                end

                DO_WRITE: begin
                    state <= INC_ADDR;
                end

                INC_ADDR: begin
                    if (mem_waddr == 1023) begin
                        state <= IDLE;
                    end else begin
                        mem_waddr <= mem_waddr + 1; 
                        state <= GET_LO;
                    end
                end

                CMD_DEC: begin
                    if (rx_ready) begin
                        if (rx_data == "D") hls_opcode <= 0; 
                        else                hls_opcode <= 1; 
                        state <= DO_START;
                    end
                end

                DO_START: begin
                    state <= WAIT_HLS;
                end

                WAIT_HLS: begin
                    if (ap_done) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule