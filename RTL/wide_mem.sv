module wide_mem #(
    parameter DATA_WIDTH = 10,
    parameter TOTAL_ITEMS = 1024
)(
    input logic clk,
    // --- PORT WRITE ---
    input logic wr_en,
    input logic [$clog2(TOTAL_ITEMS)-1:0] wr_addr,
    input logic [DATA_WIDTH-1:0]    wr_data,

    // --- PORT READ ---
    output logic [TOTAL_ITEMS-1:0][DATA_WIDTH-1:0] parallel_data
);



    (* ram_style = "distributed" *)
    logic [DATA_WIDTH-1:0] mem [0:TOTAL_ITEMS-1];

    always_ff @(posedge clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end

    genvar i;
    generate
        for (i = 0; i < TOTAL_ITEMS; i++) begin : flat_read
            assign parallel_data[i] = mem[i];
        end
    endgenerate

endmodule