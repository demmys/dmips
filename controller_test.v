`timescale 1ns/10ps

module test ();

    reg        clk;
    wire [5:0] op, funct;
    wire       branch, jump, regdst, alusrc, memwrite, memread, memtoreg, regwrite, flush;
    wire [2:0] alucont;

    // 10nsec --> 100MHz
    parameter STEP = 10;

    // generate clock to sequence tests
    always #(STEP / 2) begin
        clk <= ~clk;
    end

    controller ctl(op, funct, branch, jump, regdst, alusrc, memwrite, memread, memtoreg, regwrite, flush, alucont);

    // add  $3, $1, $2
    `define ADD  32'h00221820
    // sub  $3, $1, $2
    `define SUB  32'h00221822
    // and  $3, $1, $2
    `define AND  32'h00221824
    // or   $3, $1, $2
    `define OR   32'h00221825
    // slt  $3, $1, $2
    `define SLT  32'h0022182a
    // addi $2, $1, 20
    `define ADDI 32'h20220014
    // beq  $2, $1, 5
    `define BEQ  32'h10220005
    // j    10
    `define J    32'h0800000a
    // lb   $2, 5($1)
    `define LB   32'h80220005
    // sb   $2, 5($1)
    `define SB   32'ha0220005

    reg [31:0] instr;
    assign op = instr[31:26];
    assign funct = instr[5:0];

    initial begin
        clk <= 0;
        #STEP;

        instr <= `ADD;
        #STEP;

        if (branch !== 0 || jump !== 0 || regdst !== 1 || alusrc !== 0 || memwrite !== 0 || memread !== 0 || memtoreg !== 0 || regwrite !== 1 || flush !== 0 || alucont !== 3'b010) begin
            $display("ADD instruction failed.");
            $finish;
        end
        instr <= `SUB;
        #STEP;

        if (branch !== 0 || jump !== 0 || regdst !== 1 || alusrc !== 0 || memwrite !== 0 || memread !== 0 || memtoreg !== 0 || regwrite !== 1 || flush !== 0 || alucont !== 3'b110) begin
            $display("SUB instruction failed.");
            $finish;
        end
        instr <= `AND;
        #STEP;

        if (branch !== 0 || jump !== 0 || regdst !== 1 || alusrc !== 0 || memwrite !== 0 || memread !== 0 || memtoreg !== 0 || regwrite !== 1 || flush !== 0 || alucont !== 3'b000) begin
            $display("AND instruction failed.");
            $finish;
        end
        instr <= `OR;
        #STEP;

        if (branch !== 0 || jump !== 0 || regdst !== 1 || alusrc !== 0 || memwrite !== 0 || memread !== 0 || memtoreg !== 0 || regwrite !== 1 || alucont !== 3'b001) begin
            $display("OR instruction failed.");
            $finish;
        end
        instr <= `SLT;
        #STEP;

        if (branch !== 0 || jump !== 0 || regdst !== 1 || alusrc !== 0 || memwrite !== 0 || memread !== 0 || memtoreg !== 0 || regwrite !== 1 || flush !== 0 || alucont !== 3'b111) begin
            $display("SLT instruction failed.");
            $finish;
        end
        instr <= `ADDI;
        #STEP;

        if (branch !== 0 || jump !== 0 || regdst !== 0 || alusrc !== 1 || memwrite !== 0 || memread !== 0 || memtoreg !== 0 || regwrite !== 1 || alucont !== 3'b010) begin
            $display("ADDI instruction failed.");
            $finish;
        end
        instr <= `BEQ;
        #STEP;

        if (branch !== 1 || jump !== 0 || regdst !== 0 || alusrc !== 0 || memwrite !== 0 || memread !== 0 || memtoreg !== 0 || regwrite !== 0 || alucont !== 3'b010) begin
            $display("BEQ instruction failed.");
            $finish;
        end
        instr <= `J;
        #STEP;

        if (branch !== 0 || jump !== 1 || regdst !== 0 || alusrc !== 0 || memwrite !== 0 || memread !== 0 || memtoreg !== 0 || regwrite !== 0 || flush !== 1 || alucont !== 3'b010) begin
            $display("J instruction failed.");
            $finish;
        end
        instr <= `LB;
        #STEP;

        if (branch !== 0 || jump !== 0 || regdst !== 0 || alusrc !== 1 || memwrite !== 0 || memread !== 1 || memtoreg !== 1 || regwrite !== 1 || flush !== 0 || alucont !== 3'b010) begin
            $display("LB instruction failed.");
            $finish;
        end
        instr <= `SB;
        #STEP;

        if (branch !== 0 || jump !== 0 || regdst !== 0 || alusrc !== 1 || memwrite !== 1 || memread !== 0 || memtoreg !== 0 || regwrite !== 0 || flush !== 0 || alucont !== 3'b010) begin
            $display("SB instruction failed.");
            $finish;
        end
        $display("All green.");
        $finish;
    end

endmodule
