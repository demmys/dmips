module instrom #(
    parameter DATA_WIDTH = 32, BUS_WIDTH = 17
) (
    input  [BUS_WIDTH-1:0]  adr,
    output [DATA_WIDTH-1:0] readdata
);

    reg [DATA_WIDTH-1:0] ROM [0:(1<<(BUS_WIDTH-2))-1];

    initial begin
        $readmemh("memfile.dat", ROM);
    end

    assign readdata = ROM[adr>>2];

endmodule
