module alu #(
    parameter DATA_WIDTH = 32
) (
    input      [DATA_WIDTH-1:0] a, b,
    input      [2:0]            alucont,
    output                      zero,
    output reg [DATA_WIDTH-1:0] result
);

    wire [DATA_WIDTH-1:0] b2, sum, slt;

    assign b2 = alucont[2] ? ~b : b;
    assign sum = a + b2 + alucont[2];
    // slt should be 1 if most significant bit of sum is 1
    assign slt = sum[DATA_WIDTH-1];

    // if sum is zero, set 1
    assign zero = |sum === 0;

    always@(*)
        case(alucont[1:0])
            2'b00: result <= a & b2;
            2'b01: result <= a | b2;
            2'b10: result <= sum;
            2'b11: result <= slt;
        endcase
endmodule
