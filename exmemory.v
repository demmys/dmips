module exmemory #(
    parameter WIDTH = 32
) (
    input                clk,
    input                memwrite,
    input  [WIDTH-1:0]   adr, writedata,
    output [WIDTH-1:0]   memdata
);

    reg [WIDTH-1:0] RAM [0:65535];

    initial begin
        $readmemh("memfile.dat", RAM);
    end

    assign memdata = RAM[adr>>2];

    // read and write bytes from 32-bit word
    always @(posedge clk)
        if(memwrite)
            RAM[adr>>2] <= writedata;
endmodule
