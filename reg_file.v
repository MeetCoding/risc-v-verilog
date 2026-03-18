`default_nettype none

module reg_file (
    input         clk,
    input         write_enable,
    input  [4:0]  rs1_addr,
    input  [4:0]  rs2_addr,
    input  [4:0]  rd_addr,
    input  [31:0] write_data,
    output [31:0] rs1_data,
    output [31:0] rs2_data
);

    reg [31:0] registers[0:31];

    // Two asynchronous read ports
    assign rs1_data = (rs1_addr == 5'b0) ? 32'b0 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'b0) ? 32'b0 : registers[rs2_addr];

    // One synchronous write port
    always @(posedge clk) begin
        if (write_enable && (rd_addr != 5'b0)) begin
            registers[rd_addr] <= write_data;
        end
    end

    // Initialize registers to 0 for simulation
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            registers[i] = 32'b0;
        end
    end

endmodule
