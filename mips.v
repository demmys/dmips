//-------------------------------------------------------
// mips.v
// Max Yi (byyi@hmc.edu) and David_Harris@hmc.edu 12/9/03
// Model of subset of MIPS processor described in Ch 1
//
// Matsutani: ADDI instruction is added
//-------------------------------------------------------

// simplified MIPS processor
module mips #(
    parameter DATA_WIDTH = 32, INST_BUS_WIDTH = 32, DATA_BUS_WIDTH = 32
) (
    input                       clk, reset,
    input  [DATA_WIDTH-1:0]     imemrd, dmemrd,
    output                      dmemread, dmemwrite,
    output [INST_BUS_WIDTH-1:0] iadr,
    output [DATA_BUS_WIDTH-1:0] dadr,
    output [DATA_WIDTH-1:0]     dmemwd
);

    wire [31:0] inner_iadr, inner_dadr;
    assign iadr = inner_iadr[INST_BUS_WIDTH-1:0];
    assign dadr = inner_dadr[DATA_BUS_WIDTH-1:0];

    datapath #(DATA_WIDTH) dp(clk, reset, imemrd, dmemrd, dmemread, dmemwrite, inner_iadr, inner_dadr, dmemwd);
endmodule



module hazarddetect (
    output pcwrite
);

    assign pcwrite = 1;

endmodule



module datapath #(
    parameter DATA_WIDTH = 32
) (
    input                   clk, reset,
    input  [DATA_WIDTH-1:0] imemrd, dmemrd,
    output                  dmemread, dmemwrite,
    output [31:0]           iadr, dadr,
    output [DATA_WIDTH-1:0] dmemwd
);

    parameter NOP = 32'h20000000;

    /*
     * Instruction Fetch
     */
    reg  [31:0] if_id_pc, if_id_instr;

    wire        pcwrite, flush;
    wire [1:0]  pcsrc;
    wire [31:0] pc, nextpc, incpc, branchpc, jumppc, instr;

    assign iadr = pc;

    adder        #(32) pcadder(pc, 32'h00000004, incpc);
    mux4         #(32) pcselect(incpc, branchpc, jumppc, pc, pcsrc, nextpc);
    hazarddetect       hd(pcwrite);
    flopenr      #(32) pcupdate(clk, reset, pcwrite, nextpc, pc);
    mux2         #(32) instrselect(imemrd, NOP, flush, instr);

    always @(posedge clk) begin
        if_id_pc    <= incpc;
        if_id_instr <= instr;
    end


    /*
     * Instruction Decode
     */
    reg                   id_ex_regdst, id_ex_alusrc, id_ex_memwrite, id_ex_memread, id_ex_memtoreg, id_ex_regwrite;
    reg  [2:0]            id_ex_alucont;
    reg  [4:0]            id_ex_rs, id_ex_rt, id_ex_rd;
    reg  [31:0]           id_ex_imm;
    reg  [DATA_WIDTH-1:0] id_ex_rd1, id_ex_rd2;

    wire                  regdst, alusrc, branch, jump, memwrite, memread, memtoreg, regwrite, eq;
    wire [2:0]            alucont;
    wire [5:0]            op, funct;
    wire [4:0]            rs, rt, rd;
    wire [31:0]           imm, wd;
    wire [DATA_WIDTH-1:0] rd1, rd2;

    assign op    = if_id_instr[31:26];
    assign rs    = if_id_instr[25:21];
    assign rt    = if_id_instr[20:16];
    assign rd    = if_id_instr[15:11];
    assign funct = if_id_instr[5:0];
    assign imm   = { { 16{ if_id_instr[15] } }, if_id_instr[15:0] };

    controller ctl(op, funct, branch, jump, regdst, alusrc, memwrite, memread, memtoreg, regwrite, flush, alucont);

    regfile #(DATA_WIDTH) rf(clk, mem_wb_regwrite, rs, rt, mem_wb_wa, wd, rd1, rd2);

    adder #(32) branchadder(if_id_pc, imm << 2, branchpc);
    eqdetect #(DATA_WIDTH) ed(rd1, rd2, eq);
    assign jumppc = { if_id_pc[31:28], if_id_instr[25:0] } << 2;
    assign pcsrc = { jump, branch & eq };

    always @(posedge clk) begin
        id_ex_regdst   <= regdst;
        id_ex_alusrc   <= alusrc;
        id_ex_memwrite <= memwrite;
        id_ex_memread  <= memread;
        id_ex_memtoreg <= memtoreg;
        id_ex_regwrite <= regwrite;
        id_ex_alucont  <= alucont;
        id_ex_rd1      <= rd1;
        id_ex_rd2      <= rd2;
        id_ex_rs       <= rs;
        id_ex_rt       <= rt;
        id_ex_rd       <= rd;
        id_ex_imm      <= imm;
    end


    /*
     * Execute
     */
    reg         ex_mem_memwrite, ex_mem_memread, ex_mem_memtoreg, ex_mem_regwrite;
    reg [4:0]   ex_mem_wa;
    reg [31:0]  ex_mem_alures, ex_mem_writedata;

    wire [4:0]  wa;
    wire [31:0] alusrc2, alures;

    mux2 #(DATA_WIDTH) alusrc2select(id_ex_rd2, id_ex_imm, id_ex_alusrc, alusrc2);
    alu  #(DATA_WIDTH) alunit(id_ex_rd1, alusrc2, id_ex_alucont, alures);
    mux2 #(5)          waselect(id_ex_rt, id_ex_rd, id_ex_regdst, wa);

    always @(posedge clk) begin
        ex_mem_memwrite <= id_ex_memwrite;
        ex_mem_memread  <= id_ex_memread;
        ex_mem_memtoreg <= id_ex_memtoreg;
        ex_mem_regwrite <= id_ex_regwrite;
        ex_mem_alures   <= alures;
        ex_mem_writedata <= id_ex_rd2;
        ex_mem_wa       <= wa;
    end


    /*
     * Memory
     */
    reg        mem_wb_regwrite, mem_wb_memtoreg;
    reg [4:0]  mem_wb_wa;
    reg [31:0] mem_wb_readdata, mem_wb_alures;

    assign dadr      = ex_mem_alures;
    assign dmemwd    = ex_mem_writedata;
    assign dmemread  = ex_mem_memread;
    assign dmemwrite = ex_mem_memwrite;

    always @(posedge clk) begin
        mem_wb_regwrite <= ex_mem_regwrite;
        mem_wb_memtoreg <= ex_mem_memtoreg;
        mem_wb_wa <= ex_mem_wa;
        mem_wb_readdata <= dmemrd;
        mem_wb_alures <= ex_mem_alures;
    end


    /*
     * Write Back
     */
    mux2 #(DATA_WIDTH) wdselect(mem_wb_alures, mem_wb_readdata, mem_wb_memtoreg, wd);


    always @(posedge clk) begin
        $display("\n\n\nInstruction Fetch\n>>> pc: %h, instr: %h\n>>> incpc: %h, branchpc: %h, jumppc: %h, pcsrc: %b", pc, imemrd, incpc, branchpc, jumppc, pcsrc);
        $display("\nInstruction Decode\n>>> op: %h, rs: %h, rt: %h, rd: %h, funct: %h, imm: %h\n>>> rd1: %h, rd2: %h", op, rs, rt, rd, funct, imm, rd1, rd2);
        $display("\nExecute\n>>> alusrc1: %h, alusrc2: %h, alures: %h", id_ex_rd1, alusrc2, alures);
        $display("\nMemory\n>>> dadr: %h, dmemwd: %h, dmemread: %b, dmemwrite: %b", dadr, dmemwd, dmemread, dmemwrite);
        $display("\nWrite Back\n>>> wa: %h, wd: %h, regwrite: %h", mem_wb_wa, wd, mem_wb_regwrite);
    end

endmodule



module adder #(
    parameter WIDTH = 32
) (
    input  [WIDTH-1:0] a, b,
    output [WIDTH-1:0] y
);

    assign y = a + b;

endmodule



module eqdetect #(
    parameter WIDTH = 32
) (
    input  [WIDTH-1:0] a, b,
    output             y
);

    assign y = a == b;
endmodule



module flopenr #(
    parameter WIDTH = 32
) (
    input                  clk, reset, en,
    input      [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);

    always @(posedge clk)
        if      (reset) q <= 0;
        else if (en)    q <= d;
endmodule



module mux2 #(
    parameter WIDTH = 32
) (
    input  [WIDTH-1:0] d0, d1,
    input              s,
    output [WIDTH-1:0] y
);

    assign y = s ? d1 : d0;
endmodule



module mux4 #(
    parameter WIDTH = 32
) (
    input      [WIDTH-1:0] d0, d1, d2, d3,
    input      [1:0]       s,
    output reg [WIDTH-1:0] y
);

    always @(*)
        case(s)
            2'b00: y <= d0;
            2'b01: y <= d1;
            2'b10: y <= d2;
            2'b11: y <= d3;
        endcase
endmodule
