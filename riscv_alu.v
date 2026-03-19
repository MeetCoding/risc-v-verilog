module riscv_alu(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  ctrl,
    output reg  [31:0] res,
    output wire        zero,
    output wire        lt,
    output wire        ltu
);
    assign zero = (a == b);
    assign lt   = ($signed(a) < $signed(b));
    assign ltu  = (a < b);

    always @(*) begin
        case (ctrl)
            4'b0000: res = a + b;                        // ADD
            4'b0001: res = a - b;                        // SUB
            4'b0010: res = a << b[4:0];                  // SLL
            4'b0011: res = {31'b0, lt};                  // SLT
            4'b0100: res = {31'b0, ltu};                 // SLTU
            4'b0101: res = a ^ b;                        // XOR
            4'b0110: res = a >> b[4:0];                  // SRL
            4'b0111: res = $signed(a) >>> b[4:0];        // SRA
            4'b1000: res = a | b;                        // OR
            4'b1001: res = a & b;                        // AND
            default: res = 32'b0;
        endcase
    end
endmodule