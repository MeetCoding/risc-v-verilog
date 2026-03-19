`timescale 1ns / 1ps

module riscv_branch_cond(
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire       zero, lt, ltu,
    output reg        branch_taken
);
    always @(*) begin
        branch_taken = 1'b0;
        if (opcode == 7'b1100011) begin
            case (funct3)
                3'b000: branch_taken = zero;   // BEQ
                3'b001: branch_taken = !zero;  // BNE
                3'b100: branch_taken = lt;     // BLT
                3'b101: branch_taken = !lt;    // BGE
                3'b110: branch_taken = ltu;    // BLTU
                3'b111: branch_taken = !ltu;   // BGEU
            endcase
        end
    end
endmodule