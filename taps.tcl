# ==============================================================================
# TCL Script: Automatic Row Tap Placement (Ntap / Ptap)
#
# Purpose:
# This script automatically places N-well and P-well tap rows
# along the top and bottom boundaries of the design based on
# the design bounding box (bBox).
#
# Key Features:
# 1. Extracts design boundaries dynamically.
# 2. Calculates number of columns based on instance distribution.
# 3. Places start, intermediate, and end tap cells.
# 4. Ensures alignment and consistent spacing across the layout.
# ==============================================================================


# ==============================================================================
# 1. Initialize Design
# ==============================================================================
set myDesign [ed]


# ==============================================================================
# 2. Extract Design Boundaries (BBox)
# ==============================================================================
# BBox format: {{x_min y_min} {x_max y_max}}
set fullBBox [db::getAttr bBox -of $myDesign]

set x_min [lindex [lindex $fullBBox 0] 0]
set y_bot [lindex [lindex $fullBBox 0] 1]
set x_max [lindex [lindex $fullBBox 1] 0]
set y_top [lindex [lindex $fullBBox 1] 1]

puts "LOG: Design Boundaries -> X: $x_min to $x_max | Y: $y_bot to $y_top"


# ==============================================================================
# 3. Technology & Layout Parameters
# ==============================================================================
# Step spacing between tap cells
set step 0.074

# Device geometry references
set w_mid 0.294
set w_end 0.22
set disc_end 0.146


# ==============================================================================
# 4. Calculate Number of Columns from Layout Density
# ==============================================================================
set design [ed]
set insts [db::getAttr insts -of $design]

set xList {}

db::foreach i $insts {
    set bb [db::getAttr bBox -of $i]
    set x0 [lindex $bb 0 0]
    lappend xList $x0
}

set uniqueX [lsort -real -unique $xList]
set col_num_1 [llength $uniqueX]
set col_num [expr $col_num_1 * 2]

puts "LOG: Calculated number of columns = $col_num"


# ==============================================================================
# 5. Compute Tap Alignment Positions
# ==============================================================================
# Slight offsets for proper alignment
set y_top_final [expr $y_top + 0.003]
set y_bot_final [expr $y_bot - 0.2 + 0.003]


# ==============================================================================
# 6. Place START (Left Edge) Tap Cells
# ==============================================================================
set x_l_start [expr $x_min + 0.197]

set ni_start [rpl::createInstance "ntap_row_start" -cellName "Ntap_end" -design $myDesign]
db::setAttr origin -of $ni_start -value [list $x_l_start $y_top_final]
db::setAttr orient -of $ni_start -value "MY"

set pi_start [rpl::createInstance "ptap_row_start" -cellName "Ptap_end" -design $myDesign]
db::setAttr origin -of $pi_start -value [list $x_l_start $y_bot_final]
db::setAttr orient -of $pi_start -value "MY"


# ==============================================================================
# 7. Place Intermediate Tap Rows (Loop)
# ==============================================================================
set cur_x [expr $x_min + 0.097]

for {set i 0} {$i < $col_num - 1} {incr i} {

    set ni [rpl::createInstance "ntap_row_$i" -cellName "Ntap" -design $myDesign]
    db::setAttr origin -of $ni -value [list $cur_x $y_top_final]

    set pi [rpl::createInstance "ptap_row_$i" -cellName "Ptap" -design $myDesign]
    db::setAttr origin -of $pi -value [list $cur_x $y_bot_final]

    set last_x $cur_x
    set cur_x [expr $cur_x + $step]
}


# ==============================================================================
# 8. Place END (Right Edge) Tap Cells
# ==============================================================================
set x_nr [expr $last_x + ($w_end - $disc_end)]
set x_pr [expr $last_x + ($w_end - $disc_end)]

set ni_end [rpl::createInstance "ntap_row_end" -cellName "Ntap_end" -design $myDesign]
db::setAttr origin -of $ni_end -value [list $x_nr $y_top_final]

set pi_end [rpl::createInstance "ptap_row_end" -cellName "Ptap_end" -design $myDesign]
db::setAttr origin -of $pi_end -value [list $x_pr $y_bot_final]


# ==============================================================================
# 9. Completion Log
# ==============================================================================
puts "DONE: Tap rows aligned successfully to design boundaries"
puts "Columns used = $col_num"