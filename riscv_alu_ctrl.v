`timescale 1ns / 1ps

module riscv_alu_ctrl(
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire       funct7_bit30,
    output reg  [3:0] alu_ctrl
);
    always @(*) begin
        alu_ctrl = 4'b0000;
        if (opcode == 7'b0110011) begin // R-type
            case (funct3)
                3'b000: alu_ctrl = funct7_bit30 ? 4'b0001 : 4'b0000; // SUB : ADD
                3'b101: alu_ctrl = funct7_bit30 ? 4'b0111 : 4'b0110; // SRA : SRL
                3'b001: alu_ctrl = 4'b0010; // SLL
                3'b010: alu_ctrl = 4'b0011; // SLT
                3'b011: alu_ctrl = 4'b0100; // SLTU
                3'b100: alu_ctrl = 4'b0101; // XOR
                3'b110: alu_ctrl = 4'b1000; // OR
                3'b111: alu_ctrl = 4'b1001; // AND
            endcase
        end else if (opcode == 7'b0010011) begin // I-type
            case (funct3)
                3'b101: alu_ctrl = funct7_bit30 ? 4'b0111 : 4'b0110; // SRAI : SRLI
                3'b000: alu_ctrl = 4'b0000; // ADD
                3'b001: alu_ctrl = 4'b0010; // SLL
                3'b010: alu_ctrl = 4'b0011; // SLT
                3'b011: alu_ctrl = 4'b0100; // SLTU
                3'b100: alu_ctrl = 4'b0101; // XOR
                3'b110: alu_ctrl = 4'b1000; // OR
                3'b111: alu_ctrl = 4'b1001; // AND
            endcase
        end
    end
endmodule