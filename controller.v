module alucontrol(
    input      [1:0] aluop,
    input      [5:0] funct,
    output reg [2:0] alucont
);

    always @(*)
        case(aluop)
            2'b00  : alucont <= 3'b010;  // add for lb/sb/addi (beq/j will be settled here)
            default: case(funct)       // R-Type instructions
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
    output reg   branch, jump, regdst, alusrc, memwrite, memread, memtoreg, regwrite, flush,
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
        flush    <= 0;
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
            end
            J: begin
                jump     <= 1;
                flush    <= 1;
            end
        endcase
    end

endmodule
