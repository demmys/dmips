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
    parameter WIDTH = 32
)();

    reg                clk;
    reg                reset;
    wire               memread, memwrite;
    wire [WIDTH-1:0]   adr, writedata;
    wire [WIDTH-1:0]   memdata;
    
    // 10nsec --> 100MHz
    parameter STEP = 10;
    
    // instantiate devices to be tested
    mips dut(clk, reset, memdata, memread, memwrite, adr, writedata);
    
    // external memory for code and data
    exmemory #(WIDTH) exmem(clk, memwrite, adr, writedata, memdata);
    
    // initialize test
    initial begin
        `ifdef __POST_PR__
            $sdf_annotate("mips.sdf", top.dut, , "sdf.log", "MAXIMUM");
        `endif

        clk <= 0;
        reset <= 1;
        # (STEP * 2);

        reset <= 0;
        // dump waveform
        $dumpfile("dump.vcd");
        $dumpvars(0, top.dut);
        // stop at 1,000 cycles
        #(STEP * 25);
        $display("Simulation failed");
        $finish;
    end

    // generate clock to sequence tests
    always #(STEP / 2) begin
        clk <= ~clk;
        $display("");
    end

    always @(negedge clk) begin
        if(memwrite) begin
            $display("Data [%d] is stored in Address [%d]", writedata, adr);
            if(adr == 255 & writedata == 210)
                $display("Simulation completely successful");
            else
                $display("Simulation failed");
            $finish;
        end
    end
endmodule
