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
    assign hazard    = ex_memread && ((id_rs == ex_wa) || (id_rt == ex_wa));
    // BEQ
    assign lookahead = id_branch && (ex_branch || (((id_rs == ex_wa) || (id_rt == ex_wa)) || ((id_rs == mem_wa) || (id_rt == mem_wa))));

endmodule



module forwardunit (
    input  [4:0] id_rs, id_rt, ex_rs, ex_rt, mem_wa, wb_wa,
    input        mem_regwrite, wb_regwrite,
    output       id_rd1fw, id_rd2fw,
    output [1:0] ex_rd1fw, ex_rd2fw
);

    // id <= wb
    assign id_rd1fw = wb_regwrite && (id_rs === wb_wa);
    assign id_rd2fw = wb_regwrite && (id_rt === wb_wa);
    // { ex <= wb, ex <= mem }
    assign ex_rd1fw = { wb_regwrite && (ex_rs === wb_wa), mem_regwrite && (ex_rs === mem_wa) };
    assign ex_rd2fw = { wb_regwrite && (ex_rt === wb_wa), mem_regwrite && (ex_rt === mem_wa) };

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
    reg  [31:0] pc, if_id_pc, if_id_instr;

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
        else if (!(hazard === 1)) begin
            pc          <= nextpc;
            if_id_pc    <= incpc;
            if_id_instr <= instr;
        end
    end


    /*
     * Instruction Decode (Write Back)
     */
    reg                   id_ex_regdst, id_ex_alusrc, id_ex_branch, id_ex_memwrite, id_ex_memread, id_ex_memtoreg, id_ex_regwrite;
    reg  [2:0]            id_ex_alucont;
    reg  [4:0]            id_ex_rs, id_ex_rt, id_ex_rd;
    reg  [31:0]           id_ex_branchpc, id_ex_imm;
    reg  [DATA_WIDTH-1:0] id_ex_rd1, id_ex_rd2;

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
                    : (id_ex_branch & zero) === 1 ? 2'b11
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
    reg         ex_mem_memwrite, ex_mem_memread, ex_mem_memtoreg, ex_mem_regwrite;
    reg [4:0]   ex_mem_wa;
    reg [31:0]  ex_mem_alures, ex_mem_writedata;

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
    reg        mem_wb_regwrite, mem_wb_memtoreg;
    reg [4:0]  mem_wb_wa;
    reg [31:0] mem_wb_readdata, mem_wb_alures;

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

endmodule



module alucontrol(
    input      [1:0] aluop,
    input      [5:0] funct,
    output reg [2:0] alucont
);

    always @(*)
        case(aluop)
            2'b00  : alucont <= 3'b010; // add for lb/sb/addi (j will be settled here)
            2'b01  : alucont <= 3'b110; // sub for beq
            default: case(funct)        // R-Type instructions
                6'b100000: alucont <= 3'b010; // add (for add)
                6'b100010: alucont <= 3'b110; // subtract (for sub)
                6'b100100: alucont <= 3'b000; // logical and (for and)
                6'b100101: alucont <= 3'b001; // logical or (for or)
                6'b101010: alucont <= 3'b111; // set on less (for slt)
                default  : alucont <= 3'b101; // no operation 
            endcase
        endcase
endmodule



module controller (
    input [5:0]  op, funct,
    output reg   branch, jump, regdst, alusrc, memwrite, memread, memtoreg, regwrite,
    output [2:0] alucont
);

    parameter RTYPE = 6'b000000;
    parameter ADDI  = 6'b001000;
    parameter LB    = 6'b100000;
    parameter SB    = 6'b101000;
    parameter BEQ   = 6'b000100;
    parameter J     = 6'b000010;

    reg [1:0] aluop;

    alucontrol ac(aluop, funct, alucont);

    always @(*) begin
        branch   <= 0;
        jump     <= 0;
        regdst   <= 0;
        alusrc   <= 0;
        memwrite <= 0;
        memread  <= 0;
        memtoreg <= 0;
        regwrite <= 0;
        aluop    <= 2'b00;

        case (op)
            RTYPE: begin
                regdst   <= 1;
                regwrite <= 1;
                aluop    <= 2'b10;
            end
            ADDI: begin
                alusrc   <= 1;
                regwrite <= 1;
            end
            LB: begin
                alusrc   <= 1;
                memread  <= 1;
                memtoreg <= 1;
                regwrite <= 1;
            end
            SB: begin
                alusrc   <= 1;
                memwrite <= 1;
            end
            BEQ: begin
                branch   <= 1;
                aluop    <= 2'b01;
            end
            J: begin
                jump     <= 1;
            end
        endcase
    end

endmodule



module alu #(
    parameter DATA_WIDTH = 32
) (
    input      [DATA_WIDTH-1:0] a, b,
    input      [2:0]            alucont,
    output                      zero,
    output reg [DATA_WIDTH-1:0] result
);

    wire [DATA_WIDTH-1:0] b2, sum, slt;

    assign b2 = alucont[2] ? ~b : b;
    assign sum = a + b2 + alucont[2];
    // slt should be 1 if most significant bit of sum is 1
    assign slt = sum[DATA_WIDTH-1];

    // if sum is zero, set 1
    assign zero = !(|sum);

    always@(*)
        case(alucont[1:0])
            2'b00: result <= a & b2;
            2'b01: result <= a | b2;
            2'b10: result <= sum;
            2'b11: result <= slt;
        endcase
endmodule



module regfile #(
    parameter DATA_WIDTH = 32
) (
    input                   clk,
    input                   regwrite,
    input  [4:0]            ra1, ra2, wa,
    input  [DATA_WIDTH-1:0] wd,
    output [DATA_WIDTH-1:0] rd1, rd2
);

    reg [DATA_WIDTH-1:0] RAM [0:31];

    // three ported register file
    // read two ports combinationally
    // write third port on rising edge of clock
    // register 0 hardwired to 0
    always @(posedge clk) begin
        if (regwrite) RAM[wa] <= wd;
    end

    assign rd1 = ra1 ? RAM[ra1] : 0;
    assign rd2 = ra2 ? RAM[ra2] : 0;
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
