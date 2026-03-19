`timescale 1ns / 1ps

module riscv_processor #(parameter RESET_ADDR=32'h0, parameter ADDR_WIDTH=32)(
    input clk, reset, mem_rbusy, mem_wbusy,
    input [31:0] mem_rdata,
    output reg mem_rstrb,
    output reg [3:0] mem_wmask,
    output reg [31:0] mem_addr, mem_wdata
);
    reg [2:0] state, funct3_reg;
    reg [31:0] PC, instr, alu_out_reg, rs2_reg;
    reg [4:0] rd_reg;

    wire [6:0] op, f7; 
    wire [2:0] f3; 
    wire [4:0] rs1, rs2, rd;
    wire [31:0] iI, iS, iB, iU, iJ, rv1, rv2, alu_o, ld_data, st_wdata;
    wire [3:0] alu_c, st_wmask; 
    wire z, lt, ltu, br_taken;

    // Register File Controller Logic
    reg rf_we; reg [31:0] rf_wdata; reg [4:0] rf_waddr;

    // Submodule Instantiations
    riscv_decoder     DEC(instr, op, f3, f7, rs1, rs2, rd, iI, iS, iB, iU, iJ);
    riscv_alu_ctrl    ACT(op, f3, f7[5], alu_c);
    riscv_alu         ALU(.a(rv1), .b((op==7'b0110011||op==7'b1100011)?rv2:iI), .ctrl(alu_c), .res(alu_o), .zero(z), .lt(lt), .ltu(ltu));
    riscv_branch_cond BRN(op, f3, z, lt, ltu, br_taken);
    riscv_mem_align   MAL(funct3_reg, alu_out_reg[1:0], rs2_reg, mem_rdata, st_wdata, ld_data, st_wmask);
    riscv_regfile     RF(clk, reset, rf_we, rs1, rs2, rf_waddr, rf_wdata, rv1, rv2);

    // Combinatorial Output Control
    reg [31:0] next_pc;
    always @(*) begin
        next_pc = PC + 4; rf_we = 0; rf_waddr = rd; rf_wdata = 0;
        if (state == 3'd2) begin // S_DECODE
            if (op==7'b1100011 && br_taken) next_pc = PC + iB;
            else if (op==7'b1101111) next_pc = PC + iJ;
            else if (op==7'b1100111) next_pc = (rv1 + iI) & ~32'd1;
            
            case(op)
                7'b0110011, 7'b0010011: begin rf_we=1; rf_wdata=alu_o; end
                7'b1101111, 7'b1100111: begin rf_we=1; rf_wdata=PC+4; end
                7'b0110111: begin rf_we=1; rf_wdata=iU; end
                7'b0010111: begin rf_we=1; rf_wdata=PC+iU; end
            endcase
        end else if (state == 3'd4) begin // S_MEM_WB
            rf_we = 1; rf_waddr = rd_reg; rf_wdata = ld_data;
        end
        
        mem_addr = (state<=3'd1) ? PC : alu_out_reg;
        mem_rstrb = (state==3'd0 || state==3'd3);
        mem_wdata = st_wdata; mem_wmask = (state==3'd5) ? st_wmask : 4'b0;
    end

    // Sequential Core (Main FSM)
    always @(posedge clk) begin
        if(!reset) begin state <= 0; PC <= RESET_ADDR; end
        else case(state)
            3'd0: if(!mem_rbusy) state <= 3'd1;                                // S_FETCH
            3'd1: begin instr <= mem_rdata; state <= 3'd2; end                 // S_FETCH_WAIT
            3'd2: if(op==7'b0000011) begin alu_out_reg <= rv1+iI; rd_reg<=rd; funct3_reg<=f3; state<=3'd3; end  // LOAD
                  else if(op==7'b0100011) begin alu_out_reg <= rv1+iS; rs2_reg<=rv2; funct3_reg<=f3; state<=3'd5; end // STORE
                  else begin PC <= next_pc; state <= 3'd0; end                 // FAST EXECUTE
            3'd3: if(!mem_rbusy) state <= 3'd4;                                // S_MEM_READ
            3'd4: begin PC <= PC + 4; state <= 3'd0; end                       // S_MEM_WB
            3'd5: if(!mem_wbusy) begin PC <= PC + 4; state <= 3'd0; end        // S_MEM_WRITE
        endcase
    end
endmodule