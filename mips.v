//-------------------------------------------------------
// mips.v
// Max Yi (byyi@hmc.edu) and David_Harris@hmc.edu 12/9/03
// Model of subset of MIPS processor described in Ch 1
//
// Matsutani: ADDI instruction is added
//-------------------------------------------------------

// simplified MIPS processor
module mips #(
    parameter WIDTH = 32, REGBITS = 5
) (
    input              clk, reset,
    input  [WIDTH-1:0] memdata,
    output             memread, memwrite,
    output [WIDTH-1:0] adr, writedata
);

    wire [31:0] instr;
    wire        zero, alusrca, memtoreg, iord, pcen, regwrite, regdst, irwrite;
    wire [1:0]  aluop, pcsource, alusrcb;
    wire [2:0]  alucont;

    controller                   cont(clk, reset, instr[31:26], zero, memread, memwrite, alusrca, memtoreg, iord, pcen, regwrite, regdst, irwrite, pcsource, alusrcb, aluop);
    alucontrol                   ac(aluop, instr[5:0], alucont);
    datapath   #(WIDTH, REGBITS) dp(clk, reset, memdata, alusrca, memtoreg, iord, pcen, regwrite, regdst, irwrite, pcsource, alusrcb, alucont, zero, instr, adr, writedata);
endmodule



module controller(
    input            clk, reset,
    input      [5:0] op,
    input            zero,
    output reg       memread, memwrite, alusrca, memtoreg, iord,
    output           pcen,
    output reg       regwrite, regdst, irwrite,
    output reg [1:0] pcsource, alusrcb, aluop
);

    parameter FETCH   = 4'b0001;
    parameter DECODE  = 4'b0101;
    parameter MEMADR  = 4'b0110;
    parameter LBRD    = 4'b0111;
    parameter LBWR    = 4'b1000;
    parameter SBWR    = 4'b1001;
    parameter RTYPEEX = 4'b1010;
    parameter RTYPEWR = 4'b1011;
    parameter BEQEX   = 4'b1100;
    parameter JEX     = 4'b1101;
    parameter ADDIEX  = 4'b1110;
    parameter ADDIWR  = 4'b1111;

    parameter LB      = 6'b100000;
    parameter SB      = 6'b101000;
    parameter RTYPE   = 6'b0;
    parameter BEQ     = 6'b000100;
    parameter ADDI    = 6'b001000;
    parameter J       = 6'b000010;

    reg [3:0] state, nextstate;
    reg       pcwrite, pcwritecond;

    // state register
    always @(posedge clk)
        if(reset) state <= FETCH;
        else state <= nextstate;

    // next state logic
    always @(*)
        case(state)
            FETCH  : nextstate <= DECODE;
            DECODE : case(op)
                LB     : nextstate <= MEMADR;
                SB     : nextstate <= MEMADR;
                RTYPE  : nextstate <= RTYPEEX;
                BEQ    : nextstate <= BEQEX;
                ADDI   : nextstate <= ADDIEX;
                J      : nextstate <= JEX;
                default: nextstate <= FETCH; // should never happen
            endcase
            MEMADR : case(op)
                LB     : nextstate <= LBRD;
                SB     : nextstate <= SBWR;
                default: nextstate <= FETCH; // should never happen
            endcase
            LBRD   : nextstate <= LBWR;
            LBWR   : nextstate <= FETCH;
            SBWR   : nextstate <= FETCH;
            RTYPEEX: nextstate <= RTYPEWR;
            RTYPEWR: nextstate <= FETCH;
            BEQEX  : nextstate <= FETCH;
            JEX    : nextstate <= FETCH;
            ADDIEX : nextstate <= ADDIWR;
            ADDIWR : nextstate <= FETCH;
            default: nextstate <= FETCH; // should never happen
        endcase

    always @(*) begin
        // set all outputs to zero, then conditionally assert just the appropriate ones
        irwrite     <= 0;
        pcwrite     <= 0;
        pcwritecond <= 0;
        regwrite    <= 0;
        regdst      <= 0;
        memread     <= 0;
        memwrite    <= 0;
        alusrca     <= 0;
        alusrcb     <= 2'b00;
        aluop       <= 2'b00;
        pcsource    <= 2'b00;
        iord        <= 0;
        memtoreg    <= 0;
        case(state)
            FETCH: begin
                memread <= 1;
                irwrite <= 1;
                alusrcb <= 2'b01;
                pcwrite <= 1;
            end
            DECODE: alusrcb <= 2'b11;
            MEMADR: begin
                alusrca <= 1;
                alusrcb <= 2'b10;
            end
            LBRD: begin
                memread <= 1;
                iord    <= 1;
            end
            LBWR: begin
                regwrite <= 1;
                memtoreg <= 1;
            end
            SBWR: begin
                memwrite <= 1;
                iord     <= 1;
            end
            RTYPEEX: begin
                alusrca <= 1;
                aluop   <= 2'b10;
            end
            RTYPEWR: begin
                regdst   <= 1;
                regwrite <= 1;
            end
            BEQEX: begin
                alusrca     <= 1;
                aluop       <= 2'b01;
                pcwritecond <= 1;
                pcsource    <= 2'b01;
            end
            JEX: begin
                pcwrite  <= 1;
                pcsource <= 2'b10;
            end
            ADDIEX: begin
                alusrca <= 1;
                alusrcb <= 2'b10;
            end
            ADDIWR: begin
                regdst   <= 0;
                regwrite <= 1;
            end
        endcase
    end
    assign pcen = pcwrite | (pcwritecond & zero); // program counter enable
endmodule



module alucontrol(
    input      [1:0] aluop,
    input      [5:0] funct,
    output reg [2:0] alucont
);

    always @(*)
        case(aluop)
            2'b00  : alucont <= 3'b010;  // add for lb/sb/addi
            2'b01  : alucont <= 3'b110;  // sub (for beq)
            default: case(funct)       // R-Type instructions
                6'b100000: alucont <= 3'b010; // add (for add)
                6'b100010: alucont <= 3'b110; // subtract (for sub)
                6'b100100: alucont <= 3'b000; // logical and (for and)
                6'b100101: alucont <= 3'b001; // logical or (for or)
                6'b101010: alucont <= 3'b111; // set on less (for slt)
                default  : alucont <= 3'b101; // should never happen
            endcase
        endcase
endmodule



module datapath #(
    parameter WIDTH = 32, REGBITS = 5
) (
    input              clk, reset,
    input  [WIDTH-1:0] memdata,
    input              alusrca, memtoreg, iord, pcen, regwrite, regdst, irwrite,
    input  [1:0]       pcsource, alusrcb,
    input  [2:0]       alucont,
    output             zero,
    output [31:0]      instr,
    output [WIDTH-1:0] adr, writedata
);

    // the size of the parameters must be changed to match the WIDTH parameter
    parameter CONST_ZERO = 32'b0;
    parameter CONST_FOUR = 32'h4;

    wire [REGBITS-1:0] ra1, ra2, wa;
    wire [WIDTH-1:0]   pc, nextpc, md, rd1, rd2, wd, a, src1, src2, aluresult, aluout, imm, dest;

    // expand immediate value
    assign imm = { { (REGBITS*2+6){ instr[WIDTH-7-REGBITS*2] } }, instr[WIDTH-7-REGBITS*2:0] };

    // jump addres
    assign dest = { pc[WIDTH-1:WIDTH-5], instr[WIDTH-7:0] } << 2;

    // register file address fields
    assign ra1 = instr[WIDTH-7:WIDTH-6-REGBITS];
    assign ra2 = instr[WIDTH-7-REGBITS:WIDTH-6-REGBITS*2];

    // choose destination register file address
    mux2       #(REGBITS)        regdistmux(instr[WIDTH-7-REGBITS:WIDTH-6-REGBITS*2], instr[WIDTH-7-REGBITS:WIDTH-6-REGBITS*3], regdst, wa);

    // load instruction into register
    // enable: FETCH
    flopen     #(WIDTH)          loadinst(clk, irwrite, memdata, instr);

    // datapath

    // load next pc
    // enable: FETCH, JEX, BEQEX(if aluresult == zero)
    flopenr    #(WIDTH)          pcreg(clk, reset, pcen, nextpc, pc);

    // load memdata to md
    flop       #(WIDTH)          mdr(clk, memdata, md);

    // set readed data 1 to a(candidate of aulsrc1)
    flop       #(WIDTH)          areg(clk, rd1, a);

    // set readed data 2 to writedata(candidate of alusrc2)
    flop       #(WIDTH)          wrd(clk, rd2, writedata);

    // set aluresult to aluout(candidate of adr: exmemory address)
    flop       #(WIDTH)          res(clk, aluresult, aluout);

    // choose exmemory address
    // select1: LBRD, SBWR
    mux2       #(WIDTH)          adrmux(pc, aluout, iord, adr);

    // choose alu source 1
    // select1: MEMADR, RTYPEEX, BEQEX, ADDIEX
    mux2       #(WIDTH)          src1mux(pc, a, alusrca, src1);

    // choose alu source 2
    // select1: FETCH, select2: MEMADR, ADDIEX, select3: DECODE
    mux4       #(WIDTH)          src2mux(writedata, CONST_FOUR, imm, imm << 2, alusrcb, src2);

    // choose next pc
    // select1: BEQEX, select2: JEX
    mux4       #(WIDTH)          pcmux(aluresult, aluout, dest, CONST_ZERO, pcsource, nextpc);

    // choose write data
    // select1: LBWR
    mux2       #(WIDTH)          wdmux(aluout, md, memtoreg, wd);

    regfile    #(WIDTH, REGBITS) rf(clk, regwrite, ra1, ra2, wa, wd, rd1, rd2);
    alu        #(WIDTH)          alunit(src1, src2, alucont, aluresult);
    zerodetect #(WIDTH)          zd(aluresult, zero);

endmodule



module zerodetect #(
    parameter WIDTH = 32
) (
    input [WIDTH-1:0] a,
    output            y
);

    assign y = a == 0;
endmodule



module flop #(
    parameter WIDTH = 32
) (
    input                  clk,
    input      [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);

    always @(posedge clk)
        q <= d;
endmodule



module flopen #(
    parameter WIDTH = 32
) (
    input                  clk, en,
    input      [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);

    always @(posedge clk)
        if (en)
            q <= d;
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
        else if (en)
            q <= d;
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
