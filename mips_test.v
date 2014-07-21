`timescale 1ns/10ps

module test #(
    parameter DATA_WIDTH = 32, INST_BUS_WIDTH = 17, DATA_BUS_WIDTH = 17
)();

    reg                       clk, reset;
    wire [DATA_WIDTH-1:0]     imemrd, dmemrd;
    wire                      dmemread, dmemwrite;
    wire [INST_BUS_WIDTH-1:0] iadr;
    wire [DATA_BUS_WIDTH-1:0] dadr;
    wire [DATA_WIDTH-1:0]     dmemwd;

    // 10nsec --> 100MHz
    parameter STEP = 10;

    // generate clock to sequence tests
    always #(STEP / 2) begin
        clk <= ~clk;
    end

    mips #(DATA_WIDTH, INST_BUS_WIDTH, DATA_BUS_WIDTH) m(clk, reset, imemrd, dmemrd, dmemread, dmemwrite, iadr, dadr, dmemwd);

    instrom #(DATA_WIDTH, INST_BUS_WIDTH) ir(iadr, imemrd);
    dataram #(DATA_WIDTH, DATA_BUS_WIDTH) dr(clk, dmemwrite, dadr, dmemwd, dmemrd);



    initial begin
        clk <= 0;
        reset <= 1;
        $display("\n\n\n\n");
        #STEP;

        reset <= 0;
        if (iadr !== 32'h0) begin
            $display("Reset failed.\nExpected %h but actual is %h", 32'h0, iadr);
            $finish;
        end
        #STEP;

        if (iadr !== 32'h4) begin
            $display("First fetch failed.\nExpected %h but actual is %h", 32'h4, iadr);
            $finish;
        end
        #STEP;

        if (iadr !== 32'h8) begin
            $display("Second fetch failed.\nExpected %h but actual is %h", 32'h8, iadr);
            $finish;
        end
        #(STEP * 4);
        $display("\n\n\n\nAll green.");
        $finish;
    end

endmodule
