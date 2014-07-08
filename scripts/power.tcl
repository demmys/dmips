#
# Your design
#
set base_name "mips"
set vnet_file "mips_final.vnet"
set sdc_file  "mips.sdc"
set sdf_file  "mips.sdf"
set spef_file "mips.spef"
set saif_file "mips.saif"

#
# Libraries
#
set target_library "~matutani/lib/typical.db"
# set target_library "~matutani/lib/fast.db"
# set target_library "~matutani/lib/slow.db"
set synthetic_library "dw_foundation.sldb"
set link_library [concat "*" $target_library $synthetic_library]
set symbol_library "generic.sldb"
define_design_lib WORK -path ./WORK

#
# Read post-layout netlist
#
read_file -format verilog $vnet_file
current_design $base_name
link

#
# Delay and RC information
#
read_sdc $sdc_file
read_sdf $sdf_file
read_parasitics $spef_file

#
# Read switching activity information
#
reset_switching_activity
read_saif -input $saif_file -instance top/dut -unit ns -scale 1

# report_timing
# report_reference -hier
# report_power -hier
# quit
