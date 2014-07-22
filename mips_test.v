`timescale 1ns/10ps

module test #(
    parameter DATA_WIDTH = 32, INST_BUS_WIDTH = 17, DATA_BUS_WIDTH = 17
)();

    reg                       clk, reset;
    reg  [DATA_WIDTH-1:0]     imemrd;
    wire [INST_BUS_WIDTH-1:0] iadr;
    wire [DATA_BUS_WIDTH-1:0] dadr;
    wire                      dmemread, dmemwrite;
    wire [DATA_WIDTH-1:0]     dmemrd, dmemwd;

    // 10nsec --> 100MHz
    parameter STEP = 10;

    // generate clock to sequence tests
    always #(STEP / 2) begin
        clk <= ~clk;
    end

    mips #(DATA_WIDTH, INST_BUS_WIDTH, DATA_BUS_WIDTH) m(clk, reset, imemrd, dmemrd, dmemread, dmemwrite, iadr, dadr, dmemwd);

    dataram #(DATA_WIDTH, DATA_BUS_WIDTH) dr(clk, dmemwrite, dadr, dmemwd, dmemrd);


    `define NOP           32'h20000000
    `define RESET_R1      32'h20010000
    `define RESET_R2      32'h20020000
    `define ADDI_10_R1    32'h2001000a
    `define ADDI_10_R1_R1 32'h2021000a
    `define ADDI_10_R2    32'h2002000a
    `define ADDI_10_R2_R2 32'h2042000a
    `define JUMP_5        32'h08000005
    `define BEQ_R1_R2_10  32'h1022000a
    `define SB_R2_255     32'ha00200ff
    `define LB_R3_255     32'h800300ff
    `define SUB_R3_R1     32'h00611822
    `define SB_R3_10      32'ha003000a

    initial begin
        clk <= 0;
        reset <= 1;
        #STEP;
        // PC: 0

        reset <= 0;
        if (iadr !== 32'h0) begin
            $display("Reset failed.\nExpected %h but actual is %h", 32'h0, iadr);
            $finish;
        end
        imemrd <= `RESET_R1;
        #STEP;
        // PC: 4

        if (iadr !== 32'h4) begin
            $display("Fetch failed.\nExpected %h but actual is %h", 32'h4, iadr);
            $finish;
        end
        imemrd <= `JUMP_5;
        #STEP;
        // PC: 8

        // J flushes this
        imemrd <= `ADDI_10_R1_R1;
        #STEP;
        // PC: 14

        if (iadr !== 32'h14) begin
            $display("JUMP failed.\nExpected %h but actual is %h", 32'h14, iadr);
            $finish;
        end
        imemrd <= `ADDI_10_R1_R1;
        #STEP;
        // PC: 18

        imemrd <= `ADDI_10_R2;
        #STEP;
        // PC: 1c, REG 1=0

        imemrd <= `ADDI_10_R2_R2;
        #STEP;
        // PC: 20

        imemrd <= `BEQ_R1_R2_10;
        #STEP;
        // PC: 24, REG 1=0
        
        if (iadr !== 32'h24) begin
            $display("BEQ look-ahead failed.\nExpected %h but actual is %h", 32'h24, iadr);
            $finish;
        end
        imemrd <= `ADDI_10_R1_R1;
        #STEP;
        // PC: 28, REG 1=10

        if (iadr !== 32'h28) begin
            $display("BEQ failed.\nExpected %h but actual is %h", 32'h28, iadr);
            $finish;
        end
        imemrd <= `BEQ_R1_R2_10;
        #STEP;
        // PC: 2c, REG 1=10 2=10

        // BEQ flushes this
        imemrd <= `NOP;
        #(STEP * 2);
        // PC: 30, REG 1=10 2=10
        // PC: 54, REG 1=10 2=20

        if (iadr !== 32'h54) begin
            $display("BEQ failed.\nExpected %h but actual is %h", 32'h54, iadr);
            $finish;
        end
        imemrd <= `SB_R2_255;
        #STEP;
        // PC: 58, REG 1=20 2=20

        imemrd <= `LB_R3_255;
        #STEP;
        // PC: 5c, REG 1=20 2=20

        imemrd <= `SUB_R3_R1;
        #STEP;
        // PC: 60, REG 1=20 2=20

        imemrd <= `SB_R3_10;
        if (dadr !== 17'hff || dmemwd !== 32'h14) begin
            $display("SB failed.\nExpected write %h with data %h but actual is %h with data %h", 17'hff, 32'h14, dadr, dmemwd);
            $finish;
        end
        #STEP;
        // PC: 60, REG 1=20 2=20, MEM 255=20

        if (iadr !== 32'h60) begin
            $display("LB stall failed.\nExpected %h but actual is %h", 32'h60, iadr);
            $finish;
        end
        imemrd <= `SB_R3_10;
        if (dadr !== 17'hff || dmemrd !== 32'h14) begin
            $display("LB failed.\nExpected write %h with data %h but actual is %h with data %h", 17'hff, 32'h14, dadr, dmemrd);
            $finish;
        end
        #STEP;
        // PC: 64, REG 1=20 2=20 3=20, MEM 255=20

        imemrd <= `NOP;
        #(STEP * 2);
        // PC: 68, REG 1=20 2=20 3=20, MEM 255=20
        // PC: 6c, REG 1=20 2=20 3=0, MEM 255=20

        if (dadr !== 17'ha || dmemwd !== 32'h0) begin
            $display("SUB failed.\nExpected write %h with data %h but actual is %h with data %h", 17'hff, 32'h14, dadr, dmemwd);
            $finish;
        end
        #STEP;
        // PC: 70, REG 1=20 2=20 3=20, MEM 255=20 10=0
        $display("All green.");
        $finish;
    end

endmodule
