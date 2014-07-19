`timescale 1ns/10ps

module test #(
    parameter WIDTH = 32, REGBITS = 5
)();

    reg                clk;
    reg                memwrite;
    reg  [WIDTH-1:0]   adr;
    reg  [WIDTH-1:0]   writedata;
    wire [WIDTH-1:0]   memdata;

    // 10nsec --> 100MHz
    parameter STEP = 10;

    // generate clock to sequence tests
    always #(STEP / 2) begin
        clk <= ~clk;
    end

    exmemory #(WIDTH) exmem(clk, memwrite, adr, writedata, memdata);

    `define WRITE_ADDRESS 32'h00000700
    `define WRITE_DATA 32'h0a0a0a0a

    initial begin
        clk <= 0;
        # 22;

        adr <= 32'h0;
        #STEP;

        if (memdata !== 32'h20030000) begin
            $display("Memory read %h failed.\nExpected %h but actual is %h", adr, 32'h20030000, memdata);
            $finish;
        end
        adr <= 32'h4;
        # STEP;

        if (memdata !== 32'h20040014) begin
            $display("Memory read %h failed.\nExpected %h but actual is %h", adr, 32'h20040014, memdata);
            $finish;
        end
        adr <= 32'h18;
        #STEP

        if (memdata !== 32'ha00300ff) begin
            $display("Memory read %h failed.\nExpected %h but actual is %h", adr, 32'ha00300ff, memdata);
            $finish;
        end
        memwrite <= 1;
        adr <= `WRITE_ADDRESS;
        writedata <= `WRITE_DATA;
        # STEP;

        memwrite <= 0;
        if (memdata !== `WRITE_DATA) begin
            $display("Memory write failed.\nExpected %h but actual is %h", `WRITE_DATA, memdata);
            $finish;
        end
        $display("All green.");
        $finish;
    end

endmodule
