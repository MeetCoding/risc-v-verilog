`default_nettype none

module alu (
    input      [31:0] a,
    input      [31:0] b,
    input      [4:0]  alu_op,
    output reg [31:0] result,
    output reg        zero_flag
);

    // ALU Operation Codes
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

    always @(*) begin
        case (alu_op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_SLL:  result = a << b[4:0];
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            ALU_XOR:  result = a ^ b;
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = $signed(a) >>> b[4:0];
            ALU_OR:   result = a | b;
            ALU_AND:  result = a & b;
            default:  result = 32'hdeadbeef; // Should not happen
        endcase

        zero_flag = (result == 32'd0);
    end

endmodule
