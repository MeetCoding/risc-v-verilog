module riscv_processor #(
    parameter RESET_ADDR = 32'h00000000,
    parameter ADDR_WIDTH = 32
) (
    input  wire        clk,
    input  wire        reset,         // Active Low Reset
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    output reg  [3:0]  mem_wmask,
    input  wire [31:0] mem_rdata,
    output reg         mem_rstrb,
    input  wire        mem_rbusy,
    input  wire        mem_wbusy
);

    //--------------------------------------------------------------------------
    // State Machine Definitions
    //--------------------------------------------------------------------------
    localparam S_FETCH     = 3'd0;
    localparam S_DECODE    = 3'd1;
    localparam S_MEM_READ  = 3'd2;
    localparam S_MEM_WB    = 3'd3;
    localparam S_MEM_WRITE = 3'd4;

    reg [2:0]  state;
    reg [31:0] PC;

    // Execution tracking registers (used to hold values across memory states)
    reg [31:0] alu_out_reg;
    reg [31:0] rs2_reg;
    reg [4:0]  rd_reg;
    reg [2:0]  funct3_reg;

    //--------------------------------------------------------------------------
    // Register File
    //--------------------------------------------------------------------------
    reg [31:0] regfile [1:31];
    integer i;

    //--------------------------------------------------------------------------
    // Instruction Decoding (Combinatorial in S_DECODE)
    //--------------------------------------------------------------------------
    wire [31:0] instr  = mem_rdata;
    wire [6:0]  opcode = instr[6:0];
    wire [2:0]  funct3 = instr[14:12];
    wire [6:0]  funct7 = instr[31:25];
    wire [4:0]  rs1    = instr[19:15];
    wire [4:0]  rs2    = instr[24:20];
    wire [4:0]  rd     = instr[11:7];

    wire [31:0] rv1 = (rs1 == 0) ? 32'b0 : regfile[rs1];
    wire [31:0] rv2 = (rs2 == 0) ? 32'b0 : regfile[rs2];

    // Immediate generation
    wire [31:0] imm_I = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_S = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_B = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_U = {instr[31:12], 12'b0};
    wire [31:0] imm_J = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

    //--------------------------------------------------------------------------
    // ALU Wiring & Control
    //--------------------------------------------------------------------------
    wire [31:0] alu_op1 = rv1;
    wire [31:0] alu_op2 = (opcode == 7'b0110011 || opcode == 7'b1100011) ? rv2 : imm_I;
    
    reg  [3:0]  alu_ctrl;
    wire [31:0] alu_out;
    wire        zero, lt, ltu;

    riscv_alu ALU (
        .a(alu_op1),
        .b(alu_op2),
        .ctrl(alu_ctrl),
        .res(alu_out),
        .zero(zero),
        .lt(lt),
        .ltu(ltu)
    );

    always @(*) begin
        alu_ctrl = 4'b0000; // Default ADD
        if (opcode == 7'b0110011) begin        // R-type
            case (funct3)
                3'b000: alu_ctrl = (funct7 == 7'b0100000) ? 4'b0001 : 4'b0000; // SUB : ADD
                3'b001: alu_ctrl = 4'b0010; // SLL
                3'b010: alu_ctrl = 4'b0011; // SLT
                3'b011: alu_ctrl = 4'b0100; // SLTU
                3'b100: alu_ctrl = 4'b0101; // XOR
                3'b101: alu_ctrl = (funct7 == 7'b0100000) ? 4'b0111 : 4'b0110; // SRA : SRL
                3'b110: alu_ctrl = 4'b1000; // OR
                3'b111: alu_ctrl = 4'b1001; // AND
            endcase
        end else if (opcode == 7'b0010011) begin // I-type ALU
            case (funct3)
                3'b000: alu_ctrl = 4'b0000; // ADD
                3'b001: alu_ctrl = 4'b0010; // SLL
                3'b010: alu_ctrl = 4'b0011; // SLT
                3'b011: alu_ctrl = 4'b0100; // SLTU
                3'b100: alu_ctrl = 4'b0101; // XOR
                3'b101: alu_ctrl = (funct7 == 7'b0100000) ? 4'b0111 : 4'b0110; // SRAI : SRLI
                3'b110: alu_ctrl = 4'b1000; // OR
                3'b111: alu_ctrl = 4'b1001; // AND
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // Branch Resolution
    //--------------------------------------------------------------------------
    reg branch_taken;
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
                default: branch_taken = 1'b0;
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // Data Memory Alignment Logic (Combinatorial)
    //--------------------------------------------------------------------------
    // -- Store Formatting --
    reg [31:0] store_wdata;
    reg [3:0]  store_wmask;
    always @(*) begin
        store_wdata = 32'b0;
        store_wmask = 4'b0000;
        case (funct3_reg)
            3'b000: begin // SB (Store Byte)
                store_wdata = {4{rs2_reg[7:0]}}; // Broadcast byte to all lanes
                store_wmask = (4'b0001 << alu_out_reg[1:0]);
            end
            3'b001: begin // SH (Store Halfword)
                store_wdata = {2{rs2_reg[15:0]}}; // Broadcast halfword to all lanes
                store_wmask = alu_out_reg[1] ? 4'b1100 : 4'b0011;
            end
            3'b010: begin // SW (Store Word)
                store_wdata = rs2_reg;
                store_wmask = 4'b1111;
            end
        endcase
    end

    // -- Load Formatting --
    reg [31:0] load_formatted_data;
    wire [7:0] load_byte = (alu_out_reg[1:0] == 2'b00) ? mem_rdata[7:0]  :
                           (alu_out_reg[1:0] == 2'b01) ? mem_rdata[15:8] :
                           (alu_out_reg[1:0] == 2'b10) ? mem_rdata[23:16] : mem_rdata[31:24];
    
    wire [15:0] load_half = (alu_out_reg[1] == 1'b0) ? mem_rdata[15:0] : mem_rdata[31:16];

    always @(*) begin
        case (funct3_reg)
            3'b000: load_formatted_data = {{24{load_byte[7]}}, load_byte};   // LB (Sign extend byte)
            3'b001: load_formatted_data = {{16{load_half[15]}}, load_half};  // LH (Sign extend half)
            3'b010: load_formatted_data = mem_rdata;                         // LW (Direct pass)
            3'b100: load_formatted_data = {24'b0, load_byte};                // LBU (Zero extend byte)
            3'b101: load_formatted_data = {16'b0, load_half};                // LHU (Zero extend half)
            default: load_formatted_data = mem_rdata;
        endcase
    end

    //--------------------------------------------------------------------------
    // Memory Interface Outputs (Combinatorial tracking of state)
    //--------------------------------------------------------------------------
    always @(*) begin
        mem_addr  = 32'b0;
        mem_rstrb = 1'b0;
        mem_wdata = 32'b0;
        mem_wmask = 4'b0;
        
        case (state)
            S_FETCH, S_DECODE: begin
                mem_addr  = PC;
                mem_rstrb = (state == S_FETCH);
            end
            S_MEM_READ: begin
                mem_addr  = alu_out_reg;
                mem_rstrb = 1'b1;
            end
            S_MEM_WRITE: begin
                mem_addr  = alu_out_reg;
                mem_wdata = store_wdata;
                mem_wmask = store_wmask;
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // Synchronous Main FSM
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!reset) begin
            state <= S_FETCH;
            PC    <= RESET_ADDR;
            for (i = 1; i < 32; i = i + 1) regfile[i] <= 32'b0;
        end else begin
            case (state)
                S_FETCH: begin
                    // Wait for instruction fetch to clear busy line
                    if (!mem_rbusy) state <= S_DECODE;
                end
                
                S_DECODE: begin
                    if (opcode == 7'b0000011) begin      // LOAD
                        alu_out_reg <= rv1 + imm_I;
                        rd_reg      <= rd;
                        funct3_reg  <= funct3;
                        state       <= S_MEM_READ;
                        
                    end else if (opcode == 7'b0100011) begin // STORE
                        alu_out_reg <= rv1 + imm_S;
                        rs2_reg     <= rv2;
                        funct3_reg  <= funct3;
                        state       <= S_MEM_WRITE;
                        
                    end else begin
                        // Fast Execute for ALU, Branches, and Jumps
                        state <= S_FETCH; 
                        case (opcode)
                            7'b0110011, 7'b0010011: begin // R-type & I-type ALU
                                if (rd != 0) regfile[rd] <= alu_out;
                                PC <= PC + 4;
                            end
                            7'b1100011: begin // B-type Branch
                                if (branch_taken) PC <= PC + imm_B;
                                else PC <= PC + 4;
                            end
                            7'b1101111: begin // JAL
                                if (rd != 0) regfile[rd] <= PC + 4;
                                PC <= PC + imm_J;
                            end
                            7'b1100111: begin // JALR
                                if (rd != 0) regfile[rd] <= PC + 4;
                                PC <= (rv1 + imm_I) & ~32'd1;
                            end
                            7'b0110111: begin // LUI
                                if (rd != 0) regfile[rd] <= imm_U;
                                PC <= PC + 4;
                            end
                            7'b0010111: begin // AUIPC
                                if (rd != 0) regfile[rd] <= PC + imm_U;
                                PC <= PC + 4;
                            end
                            default: PC <= PC + 4; // Skip unknown/unsupported
                        endcase
                    end
                end
                
                S_MEM_READ: begin
                    if (!mem_rbusy) state <= S_MEM_WB;
                end
                
                S_MEM_WB: begin
                    if (rd_reg != 0) regfile[rd_reg] <= load_formatted_data;
                    PC <= PC + 4;
                    state <= S_FETCH;
                end
                
                S_MEM_WRITE: begin
                    if (!mem_wbusy) begin
                        PC <= PC + 4;
                        state <= S_FETCH;
                    end
                end
                
                default: state <= S_FETCH;
            endcase
        end
    end

endmodule