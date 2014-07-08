#
# Step 1: Setup (File --> Import Design)
#
setUIVar rda_Input ui_netlist mips.vnet
setUIVar rda_Input ui_timingcon_file mips.sdc
setUIVar rda_Input ui_topcell mips
setUIVar rda_Input ui_leffile ~matutani/lib/cells.lef
setUIVar rda_Input ui_timelib ~matutani/lib/slow.lib
setUIVar rda_Input ui_pwrnet VDD
setUIVar rda_Input ui_gndnet VSS
setUIVar rda_Input ui_cts_cell_list {CLKBUF_X1 CLKBUF_X2 CLKBUF_X3}
commitConfig

#
# Step 2: Floorplan (Floorplan --> Specify Floorplan)
#
floorPlan -s 150 150 15 15 15 15 

saveDesign floor.enc

#
# Step 3: Power ring (Power --> Power Planning --> Add Ring)
#
addRing -nets {VSS VDD} -type core_rings \
  -spacing_top 2 -spacing_bottom 2 -spacing_right 2 -spacing_left 2 \
  -width_top 4 -width_bottom 4 -width_right 4 -width_left 4 \
  -around core -jog_distance 0.095 -threshold 0.095 \
  -layer_top metal10 -layer_bottom metal10 -layer_right metal9 \
  -layer_left metal9 \
  -stacked_via_top_layer metal10 -stacked_via_bottom_layer metal1 

#
# Step 4: Power stripe (Power --> Power Planning --> Add Striple)
#
addStripe -nets {VSS VDD} -layer metal8 -width 4 -spacing 2 \
  -block_ring_top_layer_limit metal9 -block_ring_bottom_layer_limit metal7 \
  -padcore_ring_top_layer_limit metal9 -padcore_ring_bottom_layer_limit metal7 \
  -stacked_via_top_layer metal10 -stacked_via_bottom_layer metal1 \
  -set_to_set_distance 50 -xleft_offset 50 -merge_stripes_value 0.095 \
  -max_same_layer_jog_length 1.6 

#
# Step 5: Power route (Route --> Special Router)
#
sroute -nets {VSS VDD} -layerChangeRange {1 10} \
  -connect { blockPin padPin padRing corePin floatingStripe } \
  -blockPinTarget { nearestRingStripe nearestTarget } \
  -padPinPortConnect { allPort oneGeom } \
  -checkAlignedSecondaryPin 1 -blockPin useLef -allowJogging 1 \
  -crossoverViaBottomLayer 1 -allowLayerChange 1 -targetViaTopLayer 10 \
  -crossoverViaTopLayer 10 -targetViaBottomLayer 1 

saveDesign power.enc

#
# Step 6: Placement (Place --> Standard Cell)
#
placeDesign -prePlaceOpt

#
# Step 7: Optimization (preCTS) (Optimize --> Optimize Design)
#
optDesign -preCTS

#
# Step 8: Clock tree synthesis (CTS) (Clock --> Cynthesize Clock Tree)
#
addCTSCellList {CLKBUF_X1 CLKBUF_X2 CLKBUF_X3}
clockDesign -genSpecOnly Clock.ctstch
clockDesign -specFile Clock.ctstch -outDir clock_report -fixedInstBeforeCTS

saveDesign cts.enc

#
# Step 9: Clock tree check (Clock --> Display --> Display Clock Tree)
#

#
# Step 9: Optimization (postCTS) (Optimize --> Optimize Design)
#
optDesign -postCTS
optDesign -postCTS -hold

#
# Step 10: Detailed route (Route --> Nano Route --> Route)
#
setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -quiet -routeTopRoutingLayer default
setNanoRouteMode -quiet -routeBottomRoutingLayer default
setNanoRouteMode -quiet -drouteEndIteration default
setNanoRouteMode -quiet -routeWithTimingDriven true
routeDesign -globalDetail

#
# Step 11: Optimization (postRoute) (Optimize --> Optimize Design)
#
optDesign -postRoute
optDesign -postRoute -hold

saveDesign route.enc

#
# Step 12: Add fillers (Place --> Physical Cells --> Add Filler)
#
addFiller -prefix FILLER -cell FILLCELL_X1 FILLCELL_X2 FILLCELL_X4 \
  FILLCELL_X8 FILLCELL_X16 FILLCELL_X32 

#
# Step 13: Verification (LVS) (Verify --> Verify Connectivity)
#
verifyConnectivity -type all -error 1000 -warning 50

#
# Step 14: Verification (DRC) (Verify --> Verify Geometry)
#
verifyGeometry

#
# Step 15: Data out (Timing --> Extract RC, Timing --> Write SDF,
#                    File --> Save --> Netlist)
saveNetlist mips_final.vnet
isExtractRCModeSignoff
rcOut -spef mips.spef
delayCal -sdf mips.sdf -idealclock

saveDesign final.enc
