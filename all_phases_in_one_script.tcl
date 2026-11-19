# ==============================================================================
# FULL AUTOMATED ANALOG LAYOUT FLOW (COMBINED SCRIPT excluding the symbolic one)
# ==============================================================================
#*in order to work you should run the symbolic.tcl first*
# This script integrates all layout automation stages:
# 1. Finger update (nf)
# 2. Edge abutment control
# 3. Dummy tie-off (D & G → Source net)
# 4. POCUT generation
# 5. Tap row placement
# ==============================================================================


# ------------------------------
# PHASE 1: UPDATE NUMBER OF FINGERS (NF)
# ------------------------------


set nf 2
set design [ed]
set insts [db::getAttr insts -of $design]
db::foreach inst $insts {db::setAttr nf -of $inst -value $nf}



# ------------------------------
# PHASE 2: EDGE ABUTMENT CONTROL (LEFT / RIGHT)
# ------------------------------


set design [ed]

# List to store instances and their X coordinates
set instList {}

# ------------------------------------------------------------
# Collect all instances with their left X location
# ------------------------------------------------------------
db::foreach i [db::getInsts -of $design] {

    # Get bounding box of instance
    set bb [db::getAttr bBox -of $i]

    # Extract lower-left X coordinate
    set x  [lindex [lindex $bb 0] 0]

    # Store instance reference + X value
    lappend instList [list $i $x]
}

# ------------------------------------------------------------
# Sort instances by X coordinate (ascending)
# ------------------------------------------------------------
set instList [lsort -real -index 1 $instList]

# Get extreme boundary X values
set minX [lindex [lindex $instList 0] 1]
set maxX [lindex [lindex $instList end] 1]

# ------------------------------------------------------------
# Apply abutment rule to boundary instances only
# ------------------------------------------------------------
foreach inst $instList {

    # Extract stored values
    set ref [lindex $inst 0]
    set x   [lindex $inst 1]

    # If instance lies on left boundary → disable left abutment
    if {$x == $minX} {
        db::setAttr leftAbut -of $ref -value false
    } else {
        # If instance is internal (not on the far left), enable left abutment
        db::setAttr leftAbut -of $ref -value true
    }

    # If instance lies on right boundary → disable right abutment
    if {$x == $maxX} {
        db::setAttr rightAbut -of $ref -value false
    } else {
        # If instance is internal (not on the far Right), enable Right abutment
        db::setAttr rightAbut -of $ref -value true

    }
}

# ------------------------------------------------------------
# Completion message
# ------------------------------------------------------------
puts "Applied abutment rule to all edge instances."



# ------------------------------
# PHASE 3: DUMMY TIE-OFF (D & G → SOURCE)
# ------------------------------


set design [ed]
puts "--- STARTING DATABASE DUMMY TIE-OFF (D & G → Source) ---"
# --------------------------------------------------
# 2. Loop over instances
# --------------------------------------------------
db::foreach inst [db::getInsts -of $design] {

    set instName [db::getAttr name -of $inst]

    # process only dummy devices
    if {![string match "lxDummy*" $instName]} { continue }
    # --------------------------------------------------
    # 4. Get Source Net
    # --------------------------------------------------
    set sTerms [db::getInstTerms S -of $inst]
    if {[db::getCount $sTerms] == 0} {
        puts "SKIP: $instName has no S terminal"
        continue
    }

    set sTerm  [db::getIndex 0 -of $sTerms]
    set netObj [db::getAttr net -of $sTerm]

    if {$netObj == ""} {
        puts "SKIP: $instName Source not connected"
        continue
    }

    set netName [db::getAttr name -of $netObj]
    puts "Processing $instName → tying D & G to $netName"

    # --------------------------------------------------
    # 5. Tie D and G to Source net
    # --------------------------------------------------
    foreach termName {D G} {

        # remove old instTerms if exist
        set oldTerms [db::getInstTerms $termName -of $inst]
        db::foreach t $oldTerms {
            db::destroy $t
        }

        # create new connection
        set newITerm [db::createInstTerm $termName -inst $inst -net $netObj]
    }
}
puts "--- DONE ---"



# ==============================================================================
# PHASE 4: DYNAMIC POCUT GENERATION
# ==============================================================================



# 1. Initialize Design
set design [ed]

# 2. Get Design Boundaries from BBox
set fullBBox [db::getAttr bBox -of $design]
set x_min [lindex [lindex $fullBBox 0] 0]
set y_min [lindex [lindex $fullBBox 0] 1]
set x_max [lindex [lindex $fullBBox 1] 0]
set y_max [lindex [lindex $fullBBox 1] 1]

# 3. Parameters
set devHeight    0.568
set cutThickness 0.04
set inset        0.08
set lpp          {POCUT drawing}

# 4. Dynamic Row Calculation
set totalHeight [expr $y_max - $y_min]
set rowCount    [expr int($totalHeight / $devHeight)]

# 5. Horizontal Adjustment (Subtract 0.08 from both sides)
set x_start [expr $x_min + $inset]
set x_end   [expr $x_max - $inset]

puts "LOG: Detected Height: $totalHeight | Total Rows calculated: $rowCount"
puts "LOG: POCUT Width adjusted by $inset (X: $x_start to $x_end)"

# 6. Loop: Iterate based on calculated row count
# i=0 places the first cut at the top of the first row
for {set i 0} {$i < $rowCount} {incr i} {
    
    # Precise Y calculation using device height increments
    set offset   [expr $i * $devHeight]
    set currentY [expr $y_min + $devHeight + $offset]

    # Stop condition: Exclude the absolute top boundary of the design
    if {$currentY > [expr $y_max - 0.1]} { 
        puts "LOG: Skipping absolute top boundary at Y = $currentY"
        break 
    }

    # Format for grid precision
    set currentY [format "%.3f" $currentY]

    # Calculate rectangle corners
    set y1 [expr $currentY - ($cutThickness / 2.0)]
    set y2 [expr $currentY + ($cutThickness / 2.0)]
    set rectBox [list [list $x_start $y1] [list $x_end $y2]]

    # 7. Create POCUT rectangle
    le::createRectangle $rectBox \
        -design $design \
        -lpp $lpp

    puts "SUCCESS: POCUT created at Y = $currentY"
}

# 8. Final Refresh
de::redraw
puts "--- DYNAMIC POCUT PROCESS COMPLETED ---"

# ==============================================================================
# PHASE 5: TAP ROW PLACEMENT
# ==============================================================================


# ---------------------------------------------------------
# 1. Initialize Design
# ---------------------------------------------------------
set myDesign [ed]
# ---------------------------------------------------------
# 2. Get Coordinates Automatically from Design Boundaries (bBox)
# ---------------------------------------------------------
# Fetches {{x_min y_min} {x_max y_max}}
set fullBBox [db::getAttr bBox -of $myDesign]

set x_min [lindex [lindex $fullBBox 0] 0] ;# Start of block (Left)
set y_bot [lindex [lindex $fullBBox 0] 1] ;# Bottom of block
set x_max [lindex [lindex $fullBBox 1] 0] ;# End of block (Right)
set y_top [lindex [lindex $fullBBox 1] 1] ;# Top of block (Zero point for Top Taps)

puts "LOG: BBox Coordinates -> X: $x_min to $x_max | Y: $y_bot to $y_top"

# ---------------------------------------------------------
# 3. Basic Coordinates & Tech Data 
# ---------------------------------------------------------

# w_mid (0.294) - 0.22 (align) = 0.074 step
set step 0.074 
set w_mid 0.294
set w_end 0.22
set disc_end 0.146

# Calculate number of columns based on available width
set block_width [expr $x_max - $x_min]
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
set col_num [expr $col_num_1 *2]

puts "Number of col_num = $col_num"
# Top Tap: y_top + 0.003 for Alignment
# Bot Tap: y_bot - 0.2 (tap length) + 0.003 for Alignment
set y_top_final [expr $y_top + 0.003]
set y_bot_final [expr $y_bot - 0.2 + 0.003]

# ---------------------------------------------------------
# 4. Placement: START END TAPS (Left Side)
# ---------------------------------------------------------
set x_l_start [expr $x_min + 0.197]

set ni_start [rpl::createInstance "ntap_row_start" -cellName "Ntap_end" -design $myDesign]
db::setAttr origin -of $ni_start -value [list $x_l_start $y_top_final]
db::setAttr orient -of $ni_start -value "MY"

set pi_start [rpl::createInstance "ptap_row_start" -cellName "Ptap_end" -design $myDesign]
db::setAttr origin -of $pi_start -value [list $x_l_start $y_bot_final]
db::setAttr orient -of $pi_start -value "MY"

# ---------------------------------------------------------
# 5. Placement: NORMAL TAP ROWS (Loop)
# ---------------------------------------------------------
set cur_x [expr $x_min + 0.097]

for {set i 0} {$i < $col_num - 1 } {incr i} {
    set n_cell "Ntap"; set p_cell "Ptap"
    
    set ni [rpl::createInstance "ntap_row_$i" -cellName $n_cell -design $myDesign]
    db::setAttr origin -of $ni -value [list $cur_x $y_top_final]
    
    set pi [rpl::createInstance "ptap_row_$i" -cellName $p_cell -design $myDesign]
    db::setAttr origin -of $pi -value [list $cur_x $y_bot_final]

    set last_x $cur_x
    set cur_x [expr $cur_x + $step]
}

# ---------------------------------------------------------
# 6. Placement: FINAL END TAPS (Right Side)
# ---------------------------------------------------------
set x_nr [expr $last_x + ($w_end - $disc_end)]
set ni_end [rpl::createInstance "ntap_row_end" -cellName "Ntap_end" -design $myDesign]
db::setAttr origin -of $ni_end -value [list $x_nr $y_top_final]

set x_pr [expr $last_x + ($w_end - $disc_end)]
set pi_end [rpl::createInstance "ptap_row_end" -cellName "Ptap_end" -design $myDesign]
db::setAttr origin -of $pi_end -value [list $x_pr $y_bot_final]

# ---------------------------------------------------------
puts "--- TAP PLACEMENT DONE ---"
puts "number of taps = $col_num"


puts "DONE:PLACEMENT"
