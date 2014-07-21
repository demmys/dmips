`timescale 1ns/10ps

module test #(
    parameter DATA_WIDTH = 32, BUS_WIDTH = 17
)();

    reg                   clk;
    reg                   memwrite;
    reg  [BUS_WIDTH-1:0]  adr;
    reg  [DATA_WIDTH-1:0] writedata;
    wire [DATA_WIDTH-1:0] readdata;

    // 10nsec --> 100MHz
    parameter STEP = 10;

    // generate clock to sequence tests
    always #(STEP / 2) begin
        clk <= ~clk;
    end

    dataram #(DATA_WIDTH) dr(clk, memwrite, adr, writedata, readdata);

    `define WRITE_ADDRESS1 17'h00700
    `define WRITE_DATA1 32'h0a0a0a0a

    `define WRITE_ADDRESS2 17'h10000
    `define WRITE_DATA2 32'h20202020

    initial begin
        clk <= 0;
        #22;

        memwrite <= 1;
        adr <= `WRITE_ADDRESS1;
        writedata <= `WRITE_DATA1;
        #STEP;

        memwrite <= 0;
        if (readdata !== `WRITE_DATA1) begin
            $display("Memory write failed.\nExpected %h but actual is %h", `WRITE_DATA1, readdata);
            $finish;
        end
        writedata <= `WRITE_DATA2;
        #STEP;

        if (readdata !== `WRITE_DATA1) begin
            $display("Stop memory write failed.\nExpected %h but actual is %h", `WRITE_DATA1, readdata);
            $finish;
        end
        memwrite <= 1;
        adr <= `WRITE_ADDRESS2;
        #STEP;

        memwrite <= 0;
        if (readdata !== `WRITE_DATA2) begin
            $display("Memory write failed.\nExpected %h but actual is %h", `WRITE_DATA2, readdata);
            $finish;
        end
        adr <= `WRITE_ADDRESS1;
        #STEP

        if (readdata !== `WRITE_DATA1) begin
            $display("Memory read failed.\nExpected %h but actual is %h", `WRITE_DATA1, readdata);
            $finish;
        end
        $display("All green.");
        $finish;
    end

endmodule
