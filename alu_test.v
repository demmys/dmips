`timescale 1ns/10ps

module test #(
    parameter WIDTH = 32
)();

    reg              clk;
    reg  [WIDTH-1:0] a, b;
    reg  [2:0]       alucont;
    wire [WIDTH-1:0] result;

    // 10nsec --> 100MHz
    parameter STEP = 10;

    // generate clock to sequence tests
    always #(STEP / 2) begin
        clk <= ~clk;
    end

    alu #(WIDTH) alunit(a, b, alucont, result);

    `define SOURCE_A 32'h01234567
    `define SOURCE_B 32'h76543210

    `define RESULT_AND  32'h00000000
    `define RESULT_OR   32'h77777777
    `define RESULT_SUM  32'h77777777
    `define RESULT_NAND 32'h01234567
    `define RESULT_NOR  32'h89abcdef
    `define RESULT_SUB  32'h8acf1357
    `define RESULT_SLT  32'h00000001

    `define CONT_AND  3'b000
    `define CONT_OR   3'b001
    `define CONT_SUM  3'b010
    `define CONT_NAND 3'b100
    `define CONT_NOR  3'b101
    `define CONT_SUB  3'b110
    `define CONT_SLT  3'b111

    initial begin
        a <= `SOURCE_A;
        b <= `SOURCE_B;
        alucont <= `CONT_AND;
        #STEP;

        if (result !== `RESULT_AND) begin
            $display("ALU AND operation failed.\nExpected %h but actual is %h", `RESULT_AND, result);
            $finish;
        end
        alucont <= `CONT_OR;
        # STEP;

        if (result !== `RESULT_OR) begin
            $display("ALU OR operation failed.\nExpected %h but actual is %h", `RESULT_OR, result);
            $finish;
        end
        alucont <= `CONT_SUM;
        # STEP;

        if (result !== `RESULT_SUM) begin
            $display("ALU SUM operation failed.\nExpected %h but actual is %h", `RESULT_SUM, result);
            $finish;
        end
        alucont <= `CONT_NAND;
        # STEP;

        if (result !== `RESULT_NAND) begin
            $display("ALU NAND operation failed.\nExpected %h but actual is %h", `RESULT_NAND, result);
            $finish;
        end
        alucont <= `CONT_NOR;
        # STEP;

        if (result !== `RESULT_NOR) begin
            $display("ALU NOR operation failed.\nExpected %h but actual is %h", `RESULT_NOR, result);
            $finish;
        end
        alucont <= `CONT_SUB;
        # STEP;

        if (result !== `RESULT_SUB) begin
            $display("ALU SUB operation failed.\nExpected %h but actual is %h", `RESULT_SUB, result);
            $finish;
        end
        alucont <= `CONT_SLT;
        # STEP;

        if (result !== `RESULT_SLT) begin
            $display("ALU SLT operation failed.\nExpected %h but actual is %h", `RESULT_SLT, result);
            $finish;
        end
        $display("All green.");
        $finish;
    end

endmodule
