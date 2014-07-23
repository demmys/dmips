//-------------------------------------------------------
// test.v
// Max Yi (byyi@hmc.edu) and David_Harris@hmc.edu 12/9/03
// Model of subset of MIPS processor described in Ch 1
//
// Matsutani: SDF annotation is added
//-------------------------------------------------------
`timescale 1ns/10ps

// top level design for testing
module top #(
    parameter DATA_WIDTH = 32, INST_BUS_WIDTH = 17, DATA_BUS_WIDTH = 17
)();

    reg                       clk, reset;
    wire [INST_BUS_WIDTH-1:0] iadr;
    wire [DATA_BUS_WIDTH-1:0] dadr;
    wire                      dmemread, dmemwrite;
    wire [DATA_WIDTH-1:0]     imemrd, dmemrd, dmemwd;
    
    // 10nsec --> 100MHz
    parameter STEP = 10;
    
    // instantiate devices to be tested
    mips #(DATA_WIDTH, INST_BUS_WIDTH, DATA_BUS_WIDTH) dut(clk, reset, imemrd, dmemrd, dmemread, dmemwrite, iadr, dadr, dmemwd);
    
    // external memory for code and data
    dataram #(DATA_WIDTH, DATA_BUS_WIDTH) dr(clk, dmemwrite, dadr, dmemwd, dmemrd);
    instrom #(DATA_WIDTH, INST_BUS_WIDTH) ir(iadr, imemrd);
    
    // initialize test
    initial begin
        `ifdef __POST_PR__
            $sdf_annotate("mips.sdf", top.dut, , "sdf.log", "MAXIMUM");
        `endif

        clk <= 0;
        reset <= 1;
        # 22;

        reset <= 0;
        // dump waveform
        $dumpfile("dump.vcd");
        $dumpvars(0, top.dut);
        // stop at 1,000 cycles
        #(STEP * 1000);
        $display("Simulation failed");
        $finish;
    end

    // generate clock to sequence tests
    always #(STEP / 2) begin
        clk <= ~clk;
    end

    always @(negedge clk) begin
        if(dmemwrite) begin
            $display("Data [%d] is stored in Address [%d]", dmemwd, dadr);
            if(dadr == 255 & dmemwd == 210)
                $display("Simulation completely successful");
            else
                $display("Simulation failed");
            $finish;
        end
    end
endmodule



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
