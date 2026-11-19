# =========================================================
# Script: Row-Edge Abutment Fix
# =========================================================

# Description:
# This script processes dummy devices generated from symbolic
# placement (lxDummy instances).

# It groups devices into rows based on Y-coordinate proximity,
# sorts each row by X-coordinate, and disables abutment only
# for the first (leftmost) and last (rightmost) dummy in each row.

# Use case:
# - Fix edge connectivity in row-based symbolic placement
# - Prevent incorrect abutment between boundary devices
# - Ensure proper layout continuity per row

# =========================================================

# ---------------------------------------------------------
# 1. Get current design
# ---------------------------------------------------------
set design [ed]

# ---------------------------------------------------------
# 2. Collect dummy instances with coordinates
# ---------------------------------------------------------
set dummyList {}

db::foreach i [db::getInsts -of $design] {

    set name [db::getAttr name -of $i]

    # Process only symbolic dummy devices
    if {[string match "lxDummy*" $name]} {

        set bb [db::getAttr bBox -of $i]
        set x0 [lindex [lindex $bb 0] 0]
        set y0 [lindex [lindex $bb 0] 1]

        lappend dummyList [list $i $x0 $y0 $name]
    }
}

# ---------------------------------------------------------
# 3. Safety check (no dummies found)
# ---------------------------------------------------------
if {[llength $dummyList] == 0} {
    puts "LOG: No lxDummy instances found in the design."
    return
}

# ---------------------------------------------------------
# 4. Group instances into rows (based on Y proximity)
# ---------------------------------------------------------
set rowThresh 0.01
set rowList {}

foreach d $dummyList {

    set y [lindex $d 2]
    set found 0

    # Try to match existing row
    for {set idx 0} {$idx < [llength $rowList]} {incr idx} {

        set r  [lindex $rowList $idx]
        set ry [lindex [lindex $r 0] 2]

        # If same row (within threshold), append device
        if {[expr {abs($y - $ry)}] < $rowThresh} {

            set newRow [concat $r [list $d]]
            set rowList [lreplace $rowList $idx $idx $newRow]

            set found 1
            break
        }
    }

    # If no matching row found, create new row
    if {!$found} {
        lappend rowList [list $d]
    }
}

# ---------------------------------------------------------
# 5. Apply abutment fix per row
# ---------------------------------------------------------
foreach r $rowList {

    # Sort row by X-coordinate (left → right)
    set sortedRow [lsort -real -index 1 $r]

    # Get boundary devices in row
    set firstEntry [lindex $sortedRow 0]
    set lastEntry  [lindex $sortedRow end]

    set firstInst [lindex $firstEntry 0]
    set lastInst  [lindex $lastEntry 0]

    # Disable left abutment for leftmost device
    db::setAttr leftAbut -of $firstInst -value false
    puts "Applied LeftAbut=false to [lindex $firstEntry 3]"

    # Disable right abutment for rightmost device
    db::setAttr rightAbut -of $lastInst -value false
    puts "Applied RightAbut=false to [lindex $lastEntry 3]"
}

# ---------------------------------------------------------
# 6. Completion message
# ---------------------------------------------------------
puts "--- DONE: Row-based abutment fix applied successfully ---"