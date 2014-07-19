module regfile #(
    parameter WIDTH = 32, REGBITS = 5
) (
    input                clk,
    input                regwrite,
    input  [REGBITS-1:0] ra1, ra2, wa,
    input  [WIDTH-1:0]   wd,
    output [WIDTH-1:0]   rd1, rd2
);

    reg [WIDTH-1:0] RAM [0:(1<<REGBITS)-1];

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
