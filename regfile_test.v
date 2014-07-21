`timescale 1ns/10ps

module test #(
    parameter DATA_WIDTH = 32
)();

    reg                   clk;
    reg                   regwrite;
    reg  [4:0]            ra1, ra2, wa;
    reg  [DATA_WIDTH-1:0] wd;
    wire [DATA_WIDTH-1:0] rd1, rd2;

    // 10nsec --> 100MHz
    parameter STEP = 10;

    // generate clock to sequence tests
    always #(STEP / 2) begin
        clk <= ~clk;
    end

    regfile #(DATA_WIDTH) rf(clk, regwrite, ra1, ra2, wa, wd, rd1, rd2);

    `define WRITE_ADDRESS0 5'h03
    `define WRITE_DATA0 5'h14

    `define WRITE_ADDRESS1 5'h04
    `define WRITE_DATA1 5'h1d

    initial begin
        clk <= 0;
        # 22;

        ra1 <= 5'h00;
        #STEP;

        if (ra1 !== 32'h0) begin
            $display("Memory read %h with port 1 failed.\nExpected %h but actual is %h", ra1, 32'h0, rd1);
            $finish;
        end
        regwrite <= 1;
        wa <= `WRITE_ADDRESS0;
        wd <= `WRITE_DATA0;
        #STEP;

        ra1 <= `WRITE_ADDRESS0;
        wa <= `WRITE_ADDRESS1;
        wd <= `WRITE_DATA1;
        #STEP;

        if (rd1 !== `WRITE_DATA0) begin
            $display("Memory write or read %h with port 1 failed.\nExpected %h but actual is %h", ra1, `WRITE_DATA0, rd1);
            $finish;
        end
        ra2 <= `WRITE_ADDRESS1;
        # STEP;


        if (rd2 !== `WRITE_DATA1) begin
            $display("Memory write or read %h with port 2 failed.\nExpected %h but actual is %h", ra2, `WRITE_DATA1, rd2);
            $finish;
        end
        $display("All green.");
        $finish;
    end

endmodule
