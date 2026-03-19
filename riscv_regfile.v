`timescale 1ns / 1ps

module riscv_regfile(
    input  wire        clk, reset, we,
    input  wire [4:0]  rs1, rs2, rd,
    input  wire [31:0] wdata,
    output wire [31:0] rv1, rv2
);
    reg [31:0] regs [1:31];
    integer i;
    
    // Register 0 is hardwired to zero
    assign rv1 = (rs1 == 0) ? 32'b0 : regs[rs1];
    assign rv2 = (rs2 == 0) ? 32'b0 : regs[rs2];
    
    always @(posedge clk) begin
        if (!reset) begin
            for (i = 1; i < 32; i = i + 1) regs[i] <= 32'b0;
        end else if (we && rd != 0) begin
            regs[rd] <= wdata;
        end
    end
endmodule