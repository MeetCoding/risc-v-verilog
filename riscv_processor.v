`default_nettype none

module riscv_processor (
    input wire clk,
    input wire reset,

    // Instruction Memory Interface
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    // Data Memory Interface
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output reg  [3:0]  dmem_wmask,
    output wire        dmem_rstrb,
    input  wire [31:0] dmem_rdata
);

    // Core State
    reg [31:0] pc;
    reg [31:0] rf [1:31];

    // Instruction Fetch & Decode
    assign imem_addr = pc;
    wire [31:0] inst = imem_rdata;
    wire [6:0]  opcode = inst[6:0];
    wire [4:0]  rd     = inst[11:7];
    wire [2:0]  funct3 = inst[14:12];
    wire [4:0]  rs1    = inst[19:15];
    wire [4:0]  rs2    = inst[24:20];
    wire [6:0]  funct7 = inst[31:25];

    // Register File Read (x0 is hardwired to 0)
    wire [31:0] rs1_data = (rs1 != 0) ? rf[rs1] : 32'b0;
    wire [31:0] rs2_data = (rs2 != 0) ? rf[rs2] : 32'b0;

    // Immediate Generation
    reg [31:0] imm;
    always @(*) begin
        case (opcode)
            7'b0010011, 7'b0000011, 7'b1100111: imm = {{20{inst[31]}}, inst[31:20]}; // I-Type
            7'b0100011: imm = {{20{inst[31]}}, inst[31:25], inst[11:7]}; // S-Type
            7'b1100011: imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0}; // B-Type
            7'b0110111, 7'b0010111: imm = {inst[31:12], 12'b0}; // U-Type
            7'b1101111: imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0}; // J-Type
            default: imm = 32'b0;
        endcase
    end

    // ALU Operations
    wire [31:0] alu_a = (opcode == 7'b0010111) ? pc : rs1_data; // AUIPC uses PC, else rs1
    wire [31:0] alu_b = (opcode == 7'b0110011) ? rs2_data : imm; // R-Type Arith uses rs2, else imm
    reg  [31:0] alu_result;

    always @(*) begin
        if (opcode == 7'b0110011 || opcode == 7'b0010011) begin // R-Type & I-Type Arith
            case (funct3)
                3'b000: alu_result = (opcode == 7'b0110011 && funct7[5]) ? alu_a - alu_b : alu_a + alu_b; // ADD/SUB
                3'b001: alu_result = alu_a << alu_b[4:0]; // SLL
                3'b010: alu_result = {31'b0, $signed(alu_a) < $signed(alu_b)}; // SLT
                3'b011: alu_result = {31'b0, alu_a < alu_b}; // SLTU
                3'b100: alu_result = alu_a ^ alu_b; // XOR
                3'b101: alu_result = funct7[5] ? $signed(alu_a) >>> alu_b[4:0] : alu_a >> alu_b[4:0]; // SRA/SRL
                3'b110: alu_result = alu_a | alu_b; // OR
                3'b111: alu_result = alu_a & alu_b; // AND
            endcase
        end else if (opcode == 7'b0110111) begin // LUI
            alu_result = imm;
        end else begin // Default ADD for Loads, Stores, AUIPC
            alu_result = alu_a + alu_b;
        end
    end

    // Branch Conditions
    reg take_branch;
    always @(*) begin
        take_branch = 0;
        if (opcode == 7'b1100011) begin
            case (funct3)
                3'b000: take_branch = (rs1_data == rs2_data); // BEQ
                3'b001: take_branch = (rs1_data != rs2_data); // BNE
                3'b100: take_branch = ($signed(rs1_data) < $signed(rs2_data)); // BLT
                3'b101: take_branch = ($signed(rs1_data) >= $signed(rs2_data)); // BGE
                3'b110: take_branch = (rs1_data < rs2_data); // BLTU
                3'b111: take_branch = (rs1_data >= rs2_data); // BGEU
                default: take_branch = 0;
            endcase
        end
    end

    // Memory Interface Output
    wire is_load  = (opcode == 7'b0000011);
    wire is_store = (opcode == 7'b0100011);
    
    assign dmem_addr  = alu_result;
    assign dmem_rstrb = is_load;
    
    // Align write data to byte lanes for testbench integration
    reg [31:0] wdata_shifted;
    always @(*) begin
        case (funct3)
            3'b000: wdata_shifted = {4{rs2_data[7:0]}};  // SB (Repeat byte)
            3'b001: wdata_shifted = {2{rs2_data[15:0]}}; // SH (Repeat halfword)
            default: wdata_shifted = rs2_data;           // SW
        endcase
    end
    assign dmem_wdata = wdata_shifted;

    always @(*) begin
        dmem_wmask = 4'b0000;
        if (is_store) begin
            case (funct3)
                3'b000: dmem_wmask = 4'b0001 << alu_result[1:0];
                3'b001: dmem_wmask = 4'b0011 << alu_result[1:0];
                3'b010: dmem_wmask = 4'b1111;
                default: dmem_wmask = 4'b0000;
            endcase
        end
    end

    // Read Data Alignment & Extension
    reg [31:0] load_data;
    always @(*) begin
        load_data = dmem_rdata;
        if (is_load) begin
            case (funct3)
                3'b000: begin // LB
                    case (alu_result[1:0])
                        2'b00: load_data = {{24{dmem_rdata[7]}}, dmem_rdata[7:0]};
                        2'b01: load_data = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                        2'b10: load_data = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                        2'b11: load_data = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                    endcase
                end
                3'b001: load_data = alu_result[1] ? {{16{dmem_rdata[31]}}, dmem_rdata[31:16]} : {{16{dmem_rdata[15]}}, dmem_rdata[15:0]}; // LH
                3'b010: load_data = dmem_rdata; // LW
                3'b100: begin // LBU
                    case (alu_result[1:0])
                        2'b00: load_data = {24'b0, dmem_rdata[7:0]};
                        2'b01: load_data = {24'b0, dmem_rdata[15:8]};
                        2'b10: load_data = {24'b0, dmem_rdata[23:16]};
                        2'b11: load_data = {24'b0, dmem_rdata[31:24]};
                    endcase
                end
                3'b101: load_data = alu_result[1] ? {16'b0, dmem_rdata[31:16]} : {16'b0, dmem_rdata[15:0]}; // LHU
            endcase
        end
    end

    // Write Back
    wire is_jal  = (opcode == 7'b1101111);
    wire is_jalr = (opcode == 7'b1100111);
    wire reg_write_en = (opcode == 7'b0110011 || opcode == 7'b0010011 || is_load || 
                         opcode == 7'b0110111 || opcode == 7'b0010111 || is_jal || is_jalr);

    wire [31:0] reg_write_data = 
        (is_load) ? load_data :
        (is_jal || is_jalr) ? pc + 4 :
        alu_result;

    // PC Calculation
    wire [31:0] next_pc =
        (take_branch || is_jal) ? pc + imm :
        (is_jalr)               ? (rs1_data + imm) & 32'hFFFFFFFE :
        pc + 4;

    // Clocked Sequence Updates
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            pc <= 32'b0;
            for (i = 1; i < 32; i = i + 1) rf[i] <= 32'b0;
        end else begin
            pc <= next_pc;
            if (reg_write_en && rd != 0) begin
                rf[rd] <= reg_write_data;
            end
        end
    end

endmodule
