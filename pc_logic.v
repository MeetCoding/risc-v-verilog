`default_nettype none

module pc_logic (
    input         clk,
    input         reset,
    input         branch_cond,
    input         jal_op,
    input         jalr_op,
    input  [31:0] imm,
    input  [31:0] rs1_data,
    output reg [31:0] pc
);

    reg [31:0] next_pc;

    always @(*) begin
        if (jalr_op) begin
            next_pc = (rs1_data + imm) & 32'hfffffffe; // JALR
        end else if (jal_op) begin
            next_pc = pc + imm; // JAL
        end else if (branch_cond) begin
            next_pc = pc + imm; // Branch
        end else begin
            next_pc = pc + 4; // Default
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            pc <= 32'h00000000;
        end else begin
            pc <= next_pc;
        end
    end

endmodule
