MODEL = ~matutani/lib/cells.v

#
# Step 1: RTL simulation
#
sim:
	ncverilog +delay_mode_zero +access+r test.v mips.v | tee sim.log

#
# Step 2: Synthesis
#
syn:
	dc_shell-xg-t -f scripts/syn.tcl | tee syn.log

#
# Step 3: Place-and-route
#
par:
	velocity -init scripts/par.tcl | tee par.log

#
# Step 4: Static timing analysis
#
sta:
	dc_shell-xg-t -f scripts/sta.tcl | tee sta.log

#
# Step 5: Delay simulation 
#
dsim:
	ncverilog +define+__POST_PR__ +access+r -v ${MODEL} test.v mips_final.vnet | tee dsim.log

#
# Step 6: Power estimation 
#
power:
	vcd2saif -input dump.vcd -output mips.saif
	dc_shell-xg-t -f scripts/power.tcl | tee power.log

#
# Remove unnecessary files
#
clean:
	rm -rf INCA_libs ncverilog.log dump.trn dump.dsn sdf.log mips.saif
	rm -rf command.log default.svf WORK *.enc.dat *.enc
	rm -rf encounter.* *.old *.rpt *.rguide *.cts_trace clock_report appOption.dat Clock.ctstch timingReports
	rm -rf CTS_RP_MOVE.txt mips.ctsrpt

allclean:
	make clean
	rm -f sim.log syn.log par.log sta.log power.log dsim.log dump.vcd
	rm -f mips.vnet mips_final.vnet mips.sdc mips.sdf mips.spef mips.sdf.X
	rm -rf .qrc.leflist .qx.cmd .qx.def .routing_guide.rgf .timing_file.tif .simvision
