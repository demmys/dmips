module alu #(
    parameter WIDTH = 32
) (
    input      [WIDTH-1:0] a, b,
    input      [2:0]       alucont,
    output reg [WIDTH-1:0] result
);

    wire [WIDTH-1:0] b2, sum, slt;

    assign b2 = alucont[2] ? ~b : b;
    assign sum = a + b2 + alucont[2];
    // slt should be 1 if most significant bit of sum is 1
    assign slt = sum[WIDTH-1];

    always@(*)
        case(alucont[1:0])
            2'b00: result <= a & b2;
            2'b01: result <= a | b2;
            2'b10: result <= sum;
            2'b11: result <= slt;
        endcase
endmodule
