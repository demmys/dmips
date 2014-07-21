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
