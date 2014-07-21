module dataram #(
    parameter DATA_WIDTH = 32, BUS_WIDTH = 17
) (
    input                   clk,
    input                   memwrite,
    input  [BUS_WIDTH-1:0]  adr,
    input  [DATA_WIDTH-1:0] writedata,
    output [DATA_WIDTH-1:0] readdata
);

    reg [DATA_WIDTH-1:0] RAM [0:(1<<(BUS_WIDTH-2))-1];

    assign readdata = RAM[adr>>2];

    // read and write bytes from 32-bit word
    always @(posedge clk)
        if(memwrite)
            RAM[adr>>2] <= writedata;
endmodule
