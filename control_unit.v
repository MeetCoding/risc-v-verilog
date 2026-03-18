`default_nettype none

module control_unit (
    input      [6:0]  opcode,
    input      [2:0]  funct3,
    input      [6:0]  funct7,
    input             zero_flag,
    input             alu_lt_flag, // Assuming this comes from ALU result[0]

    output reg [4:0]  alu_op,
    output reg        alu_src_a_sel,
    output reg        alu_src_b_sel,
    output reg        reg_write_en,
    output reg [1:0]  mem_to_reg_sel,
    output reg        mem_read_en,
    output reg        mem_write_en,
    output reg        branch_cond,
    output reg [2:0]  imm_type_sel,
    output reg        jal_op,
    output reg        jalr_op
);

    // Opcodes
    parameter R_TYPE   = 7'b0110011;
    parameter I_TYPE_A = 7'b0010011; // Arith/Logic
    parameter I_TYPE_L = 7'b0000011; // Load
    parameter I_TYPE_J = 7'b1100111; // JALR
    parameter S_TYPE   = 7'b0100011;
    parameter B_TYPE   = 7'b1100011;
    parameter LUI      = 7'b0110111;
    parameter AUIPC    = 7'b0010111;
    parameter JAL      = 7'b1101111;

    // ALU operations from alu.v
    parameter ALU_ADD  = 5'b00000;
    parameter ALU_SUB  = 5'b00001;
    parameter ALU_SLL  = 5'b00010;
    parameter ALU_SLT  = 5'b00011;
    parameter ALU_SLTU = 5'b00100;
    parameter ALU_XOR  = 5'b00101;
    parameter ALU_SRL  = 5'b00110;
    parameter ALU_SRA  = 5'b00111;
    parameter ALU_OR   = 5'b01000;
    parameter ALU_AND  = 5'b01001;

    // Immediate types from imm_gen.v
    parameter IMM_I_TYPE = 3'b000;
    parameter IMM_S_TYPE = 3'b001;
    parameter IMM_B_TYPE = 3'b010;
    parameter IMM_U_TYPE = 3'b011;
    parameter IMM_J_TYPE = 3'b100;

    // Control Signal values
    parameter PC_SEL = 1'b1;
    parameter RS1_SEL = 1'b0;

    parameter IMM_SEL = 1'b1;
    parameter RS2_SEL = 1'b0;

    parameter MTR_ALU_RES = 2'b00;
    parameter MTR_MEM_DATA = 2'b01;
    parameter MTR_PC_4 = 2'b10;


    always @(*) begin
        // Default values
        alu_op = ALU_ADD;
        alu_src_a_sel = RS1_SEL;
        alu_src_b_sel = RS2_SEL;
        reg_write_en = 1'b0;
        mem_to_reg_sel = MTR_ALU_RES;
        mem_read_en = 1'b0;
        mem_write_en = 1'b0;
        branch_cond = 1'b0;
        imm_type_sel = IMM_I_TYPE;
        jal_op = 1'b0;
        jalr_op = 1'b0;

        case (opcode)
            R_TYPE: begin
                reg_write_en = 1'b1;
                case (funct3)
                    3'b000: alu_op = (funct7 == 7'b0100000) ? ALU_SUB : ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                endcase
            end
            I_TYPE_A: begin
                reg_write_en = 1'b1;
                alu_src_b_sel = IMM_SEL;
                imm_type_sel = IMM_I_TYPE;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                endcase
            end
            I_TYPE_L: begin
                reg_write_en = 1'b1;
                mem_read_en = 1'b1;
                alu_src_b_sel = IMM_SEL;
                mem_to_reg_sel = MTR_MEM_DATA;
                imm_type_sel = IMM_I_TYPE;
                alu_op = ALU_ADD;
            end
            I_TYPE_J: begin // JALR
                jalr_op = 1'b1;
                reg_write_en = 1'b1;
                mem_to_reg_sel = MTR_PC_4;
                imm_type_sel = IMM_I_TYPE;
                alu_op = ALU_ADD; // Will be used to calculate target address
            end
            S_TYPE: begin
                mem_write_en = 1'b1;
                alu_src_b_sel = IMM_SEL;
                imm_type_sel = IMM_S_TYPE;
                alu_op = ALU_ADD;
            end
            B_TYPE: begin
                imm_type_sel = IMM_B_TYPE;
                case (funct3)
                    3'b000: branch_cond = zero_flag;       // BEQ
                    3'b001: branch_cond = ~zero_flag;      // BNE
                    3'b100: branch_cond = alu_lt_flag;     // BLT
                    3'b101: branch_cond = ~alu_lt_flag;    // BGE
                    3'b110: branch_cond = alu_lt_flag;     // BLTU
                    3'b111: branch_cond = ~alu_lt_flag;    // BGEU
                endcase;
                 case (funct3)
                    3'b000, 3'b001: alu_op = ALU_SUB; // For BEQ, BNE
                    3'b100, 3'b101: alu_op = ALU_SLT; // For BLT, BGE
                    3'b110, 3'b111: alu_op = ALU_SLTU; // For BLTU, BGEU
                endcase
            end
            LUI: begin
                reg_write_en = 1'b1;
                alu_src_a_sel = RS1_SEL; //rs1 should be 0 for LUI
                alu_src_b_sel = IMM_SEL; 
                imm_type_sel = IMM_U_TYPE;
                alu_op = ALU_ADD; 
            end
            AUIPC: begin
                reg_write_en = 1'b1;
                alu_src_a_sel = PC_SEL;
                alu_src_b_sel = IMM_SEL;
                imm_type_sel = IMM_U_TYPE;
                alu_op = ALU_ADD;
            end
            JAL: begin
                jal_op = 1'b1;
                reg_write_en = 1'b1;
                mem_to_reg_sel = MTR_PC_4;
                imm_type_sel = IMM_J_TYPE;
                // This will need to be handled in PC logic
            end
        endcase
    end

endmodule
