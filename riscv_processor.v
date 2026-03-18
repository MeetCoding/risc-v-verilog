`default_nettype none

module riscv_processor (
    input clk,
    input reset,

    // Memory Interface
    output [31:0] mem_addr,
    output [31:0] mem_wdata,
    output [3:0]  mem_wmask,
    output        mem_rstrb,
    input  [31:0] mem_rdata,
    input         mem_rbusy,
    input         mem_wbusy
);

    // PC and Instruction
    wire [31:0] pc;
    wire [31:0] inst;

    // Control Unit signals
    wire [4:0]  alu_op;
    wire        alu_src_a_sel;
    wire        alu_src_b_sel;
    wire        reg_write_en;
    wire [1:0]  mem_to_reg_sel;
    wire        mem_read_en;
    wire        mem_write_en;
    wire        branch_cond;
    wire [2:0]  imm_type_sel;
    wire        jal_op;
    wire        jalr_op;

    // Imm Gen
    wire [31:0] imm;

    // Reg File
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] reg_write_data;

    // ALU
    wire [31:0] alu_a;
    wire [31:0] alu_b;
    wire [31:0] alu_result;
    wire        alu_zero_flag;
    wire        alu_lt_flag = alu_result[0];

    // Datapath
    assign inst = mem_rdata;

    pc_logic pc_logic_inst (
        .clk(clk),
        .reset(reset),
        .branch_cond(branch_cond),
        .jal_op(jal_op),
        .jalr_op(jalr_op),
        .imm(imm),
        .rs1_data(rs1_data),
        .pc(pc)
    );

    control_unit cu_inst (
        .opcode(inst[6:0]),
        .funct3(inst[14:12]),
        .funct7(inst[31:25]),
        .zero_flag(alu_zero_flag),
        .alu_lt_flag(alu_lt_flag),
        .alu_op(alu_op),
        .alu_src_a_sel(alu_src_a_sel),
        .alu_src_b_sel(alu_src_b_sel),
        .reg_write_en(reg_write_en),
        .mem_to_reg_sel(mem_to_reg_sel),
        .mem_read_en(mem_read_en),
        .mem_write_en(mem_write_en),
        .branch_cond(branch_cond),
        .imm_type_sel(imm_type_sel),
        .jal_op(jal_op),
        .jalr_op(jalr_op)
    );

    reg_file rf_inst (
        .clk(clk),
        .write_enable(reg_write_en),
        .rs1_addr(inst[19:15]),
        .rs2_addr(inst[24:20]),
        .rd_addr(inst[11:7]),
        .write_data(reg_write_data),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    imm_gen ig_inst (
        .inst(inst),
        .imm_type_sel(imm_type_sel),
        .imm(imm)
    );

    assign alu_a = alu_src_a_sel ? pc : rs1_data;
    assign alu_b = alu_src_b_sel ? imm : rs2_data;

    alu alu_inst (
        .a(alu_a),
        .b(alu_b),
        .alu_op(alu_op),
        .result(alu_result),
        .zero_flag(alu_zero_flag)
    );

    // Memory Interface
    assign mem_addr = (mem_read_en | mem_write_en) ? alu_result : pc;
    assign mem_rstrb = ~mem_write_en; 
    assign mem_wdata = rs2_data;
    
    reg [3:0] wmask;
    always@(*) begin
        if(mem_write_en) begin
            case(inst[14:12]) //funct3
                 3'b000: wmask = 4'b1 << alu_result[1:0]; //SB
                 3'b001: wmask = 4'b11 << alu_result[1:0]; //SH
                 3'b010: wmask = 4'b1111; //SW
                 default: wmask = 4'b0;
            endcase
        end else begin
            wmask = 4'b0;
        end
    end
    assign mem_wmask = wmask;

    // Write Back
    reg [31:0] load_data_extended;
    always @(*) begin
        if (mem_read_en) begin
            case (inst[14:12]) // funct3 for loads
                3'b000: load_data_extended = {{24{mem_rdata[7]}}, mem_rdata[7:0]};   // LB
                3'b001: load_data_extended = {{16{mem_rdata[15]}}, mem_rdata[15:0]}; // LH
                3'b010: load_data_extended = mem_rdata;                            // LW
                3'b100: load_data_extended = {24'b0, mem_rdata[7:0]};               // LBU
                3'b101: load_data_extended = {16'b0, mem_rdata[15:0]};             // LHU
                default: load_data_extended = mem_rdata;
            endcase
        end else begin
            load_data_extended = 32'hdeadbeef;
        end
    end

    // mem_to_reg_sel: 00: ALU, 01: Mem, 10: PC+4
    assign reg_write_data = (mem_to_reg_sel == 2'b01) ? load_data_extended :
                            (mem_to_reg_sel == 2'b10) ? pc + 4 :
                            alu_result;

endmodule
