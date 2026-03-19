`timescale 1ns / 1ps

module riscv_decoder(
    input  wire [31:0] instr,
    output wire [6:0]  opcode,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,
    output wire [4:0]  rs1, rs2, rd,
    output wire [31:0] imm_I, imm_S, imm_B, imm_U, imm_J
);
    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];
    
    assign imm_I  = {{20{instr[31]}}, instr[31:20]};
    assign imm_S  = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign imm_B  = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    assign imm_U  = {instr[31:12], 12'b0};
    assign imm_J  = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
endmodule