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
    input       id_branch, ex_branch, ex_memread,
    input [4:0] id_rs, id_rt, ex_wa, mem_wa,
    output      hazard, lookahead
);

    // LB
    assign hazard    = (ex_memread && ((id_rs == ex_wa) || (id_rt == ex_wa))) === 1;
    // BEQ
    assign lookahead = (id_branch && (ex_branch || (((id_rs == ex_wa) || (id_rt == ex_wa)) || ((id_rs == mem_wa) || (id_rt == mem_wa))))) === 1;

endmodule



module forwardunit (
    input  [4:0] id_rs, id_rt, ex_rs, ex_rt, mem_wa, wb_wa,
    input        mem_regwrite, wb_regwrite,
    output       id_rd1fw, id_rd2fw,
    output [1:0] ex_rd1fw, ex_rd2fw
);

    // id <= wb
    assign id_rd1fw = (wb_regwrite && (id_rs === wb_wa)) === 1;
    assign id_rd2fw = (wb_regwrite && (id_rt === wb_wa)) === 1;
    // { ex <= wb, ex <= mem }
    assign ex_rd1fw = { (wb_regwrite && (ex_rs === wb_wa)) === 1, (mem_regwrite && (ex_rs === mem_wa)) === 1 };
    assign ex_rd2fw = { (wb_regwrite && (ex_rt === wb_wa)) === 1, (mem_regwrite && (ex_rt === mem_wa)) === 1 };

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
     * Registers
     */
    // Instruction Fetch
    reg  [31:0] pc, if_id_pc, if_id_instr;
    // Instruction Decode
    reg                   id_ex_regdst, id_ex_alusrc, id_ex_branch, id_ex_memwrite, id_ex_memread, id_ex_memtoreg, id_ex_regwrite;
    reg  [2:0]            id_ex_alucont;
    reg  [4:0]            id_ex_rs, id_ex_rt, id_ex_rd;
    reg  [31:0]           id_ex_branchpc, id_ex_imm;
    reg  [DATA_WIDTH-1:0] id_ex_rd1, id_ex_rd2;
    // Execute
    reg         ex_mem_memwrite, ex_mem_memread, ex_mem_memtoreg, ex_mem_regwrite;
    reg [4:0]   ex_mem_wa;
    reg [31:0]  ex_mem_alures, ex_mem_writedata;
    // Memory
    reg        mem_wb_regwrite, mem_wb_memtoreg;
    reg [4:0]  mem_wb_wa;
    reg [31:0] mem_wb_readdata, mem_wb_alures;


    /*
     * Instruction Fetch
     */
    wire        hazard, lookahead, if_flush, id_flush;
    wire [1:0]  pcsrc;
    wire [31:0] nextpc, incpc, branchpc, ex_branchpc, jumppc, instr;

    // wiring
    assign iadr = pc;
    adder        #(32) pcadder(pc, 32'h00000004, incpc);
    mux4         #(32) pcselect(incpc, jumppc, branchpc, id_ex_branchpc, pcsrc, nextpc);
    mux2         #(32) instrselect(imemrd, NOP, if_flush, instr);

    // flop
    always @(posedge clk or posedge reset) begin
        if (reset) pc <= 32'h00000000;
        else if (!hazard) begin
            pc          <= nextpc;
            if_id_pc    <= incpc;
            if_id_instr <= instr;
        end
    end


    /*
     * Instruction Decode (Write Back)
     */
    wire                  regdst, alusrc, branch, jump, memwrite, memread, memtoreg, regwrite, eq, id_rd1fw, id_rd2fw, zero;
    wire [2:0]            alucont;
    wire [5:0]            op, funct;
    wire [4:0]            rs, rt, rd;
    wire [31:0]           imm, wd;
    wire [DATA_WIDTH-1:0] rd1, rd2, fw_rd1, fw_rd2;

    // wiring
    assign op     = if_id_instr[31:26];
    assign rs     = if_id_instr[25:21];
    assign rt     = if_id_instr[20:16];
    assign rd     = if_id_instr[15:11];
    assign funct  = if_id_instr[5:0];
    assign imm    = { { 16{ if_id_instr[15] } }, if_id_instr[15:0] };
    assign jumppc = { if_id_pc[31:28], if_id_instr[25:0] } << 2;
    assign pcsrc  = jump === 1 ? 2'b01
                    : (branch & eq & !(lookahead || hazard)) === 1 ? 2'b10
                    : id_ex_branch & zero ? 2'b11
                    : 2'b00;
    controller               ctl(op, funct, branch, jump, regdst, alusrc, memwrite, memread, memtoreg, regwrite, alucont);
    regfile    #(DATA_WIDTH) rf(clk, mem_wb_regwrite, rs, rt, mem_wb_wa, wd, rd1, rd2);
    adder      #(32)         branchadder(if_id_pc, imm << 2, branchpc);
    eqdetect   #(DATA_WIDTH) ed(fw_rd1, fw_rd2, eq);

    // branch hazard operation
    assign if_flush  = |pcsrc;
    assign id_flush  = &pcsrc;

    // data forwrding operation
    mux2 #(DATA_WIDTH) id_rd1select(rd1, wd, id_rd1fw, fw_rd1);
    mux2 #(DATA_WIDTH) id_rd2select(rd2, wd, id_rd2fw, fw_rd2);

    // flop
    always @(posedge clk) begin
        id_ex_regdst   <= regdst;
        id_ex_alusrc   <= alusrc;
        id_ex_branch   <= lookahead && (hazard || id_flush) ? 0 : branch;
        id_ex_memwrite <= hazard || id_flush ? 0 : memwrite;
        id_ex_memread  <= memread;
        id_ex_memtoreg <= memtoreg;
        id_ex_regwrite <= hazard || id_flush ? 0 : regwrite;
        id_ex_alucont  <= alucont;
        id_ex_rd1      <= fw_rd1;
        id_ex_rd2      <= fw_rd2;
        id_ex_rs       <= rs;
        id_ex_rt       <= rt;
        id_ex_rd       <= rd;
        id_ex_imm      <= imm;
        id_ex_branchpc <= branchpc;
    end


    /*
     * Execute
     */
    wire [1:0]  ex_rd1fw, ex_rd2fw;
    wire [4:0]  wa;
    wire [31:0] fw_id_ex_rd1, fw_id_ex_rd2, alusrc2, alures;

    // wiring
    mux2 #(DATA_WIDTH) alusrc2select(fw_id_ex_rd2, id_ex_imm, id_ex_alusrc, alusrc2);
    alu  #(DATA_WIDTH) alunit(fw_id_ex_rd1, alusrc2, id_ex_alucont, zero, alures);
    mux2 #(5)          waselect(id_ex_rt, id_ex_rd, id_ex_regdst, wa);

    // data hazard operation
    hazarddetect       hd(branch, id_ex_branch, id_ex_memread, rs, rt, wa, ex_mem_wa, hazard, lookahead);

    // data forwrding operation
    forwardunit        fwu(rs, rt, id_ex_rs, id_ex_rt, ex_mem_wa, mem_wb_wa, ex_mem_regwrite, mem_wb_regwrite, id_rd1fw, id_rd2fw, ex_rd1fw, ex_rd2fw);
    mux4 #(DATA_WIDTH) ex_rd1select(id_ex_rd1, ex_mem_alures, wd, ex_mem_alures, ex_rd1fw, fw_id_ex_rd1);
    mux4 #(DATA_WIDTH) ex_rd2select(id_ex_rd2, ex_mem_alures, wd, ex_mem_alures, ex_rd2fw, fw_id_ex_rd2);

    // flop
    always @(posedge clk) begin
        ex_mem_memwrite <= id_ex_memwrite;
        ex_mem_memread  <= id_ex_memread;
        ex_mem_memtoreg <= id_ex_memtoreg;
        ex_mem_regwrite <= id_ex_regwrite;
        ex_mem_alures   <= alures;
        ex_mem_writedata <= fw_id_ex_rd2;
        ex_mem_wa       <= wa;
    end


    /*
     * Memory
     */
    // wiring
    assign dadr      = ex_mem_alures;
    assign dmemwd    = ex_mem_writedata;
    assign dmemread  = ex_mem_memread;
    assign dmemwrite = ex_mem_memwrite;

    // flop
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
    // wiring
    mux2 #(DATA_WIDTH) wdselect(mem_wb_alures, mem_wb_readdata, mem_wb_memtoreg, wd);


    /*
    always @(posedge clk) begin
        $display("\n\n\nInstruction Fetch\n___ pc: %h, instr: %h\n___ incpc: %h, branchpc: %h, jumppc: %h, pcsrc: %b (jump: %b, branch: %b, eq: %b, lookahead: %b, hazard: %b, ex_branch: %b, zero: %b)", pc, imemrd, incpc, branchpc, jumppc, pcsrc, jump, branch, eq, lookahead, hazard, id_ex_branch, zero);
        $display("\nInstruction Decode\n___ op: %h, rs: %h, rt: %h, rd: %h, funct: %h, imm: %h\n___ rd1: %h, rd2: %h, rd1_forwarded: %b, rd2_forwarded: %b", op, rs, rt, rd, funct, imm, fw_rd1, fw_rd2, id_rd1fw, id_rd2fw);
        $display("\nExecute\n___ alusrc1: %h, alusrc2: %h, alures: %h, ex_rd1fw: %b, ex_rd2fw: %b, branchpc: %h", fw_id_ex_rd1, alusrc2, alures, ex_rd1fw, ex_rd2fw, id_ex_branchpc);
        $display("\nMemory\n___ dmem_address: %h, dmem_rd: %h, dmem_wd: %h, memread: %b, memwrite: %b", dadr, dmemrd, dmemwd, dmemread, dmemwrite);
        $display("\nWrite Back\n___ wa: %h, wd: %h, memtoreg: %b, regwrite: %b", mem_wb_wa, wd, mem_wb_memtoreg, mem_wb_regwrite);
    end
    */

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

    assign y = a === b;
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
