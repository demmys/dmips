`timescale 1ns/10ps

module test #(
    parameter DATA_WIDTH = 32, BUS_WIDTH = 17
)();

    reg                   clk;
    reg  [BUS_WIDTH-1:0]  adr;
    wire [DATA_WIDTH-1:0] readdata;

    // 10nsec --> 100MHz
    parameter STEP = 10;

    // generate clock to sequence tests
    always #(STEP / 2) begin
        clk <= ~clk;
    end

    instrom #(DATA_WIDTH) ir(adr, readdata);

    `define WRITE_ADDRESS 32'h00000700
    `define WRITE_DATA 32'h0a0a0a0a

    initial begin
        clk <= 0;
        #STEP;

        adr <= 32'h0;
        #STEP;

        if (readdata !== 32'h20030000) begin
            $display("Memory read %h failed.\nExpected %h but actual is %h", adr, 32'h20030000, readdata);
            $finish;
        end
        adr <= 32'h4;
        # STEP;

        if (readdata !== 32'h20040014) begin
            $display("Memory read %h failed.\nExpected %h but actual is %h", adr, 32'h20040014, readdata);
            $finish;
        end
        adr <= 32'h18;
        #STEP

        if (readdata !== 32'ha00300ff) begin
            $display("Memory read %h failed.\nExpected %h but actual is %h", adr, 32'ha00300ff, readdata);
            $finish;
        end
        $display("All green.");
        $finish;
    end

endmodule
