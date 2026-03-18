`default_nettype none

module imm_gen (
    input      [31:0] inst,
    input      [2:0]  imm_type_sel,
    output reg [31:0] imm
);

    parameter IMM_I_TYPE = 3'b000;
    parameter IMM_S_TYPE = 3'b001;
    parameter IMM_B_TYPE = 3'b010;
    parameter IMM_U_TYPE = 3'b011;
    parameter IMM_J_TYPE = 3'b100;

    always @(*) begin
        case (imm_type_sel)
            IMM_I_TYPE: imm = {{20{inst[31]}}, inst[31:20]};
            IMM_S_TYPE: imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
            IMM_B_TYPE: imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
            IMM_U_TYPE: imm = {inst[31:12], 12'b0};
            IMM_J_TYPE: imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            default: imm = 32'hdeadbeef; // Should not happen
        endcase
    end

endmodule
