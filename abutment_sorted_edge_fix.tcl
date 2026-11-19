# =========================================================
# Script: Sorted Edge Abutment Fix (the used one)
# =========================================================

# Description:
# This script sorts all instances based on X-coordinate
# and identifies boundary devices as the first and last
# elements in the sorted list.

# Advantage:
# - More stable than raw min/max detection
# - Handles layout precision variations better

# =========================================================

# ---------------------------------------------------------
# 1. Get current design
# ---------------------------------------------------------
set design [ed]

# ---------------------------------------------------------
# 2. Collect instances with X positions
# ---------------------------------------------------------
set instList {}

db::foreach i [db::getInsts -of $design] {

    set bb [db::getAttr bBox -of $i]
    set x  [lindex [lindex $bb 0] 0]

    lappend instList [list $i $x]
}

# ---------------------------------------------------------
# 3. Sort instances by X coordinate
# ---------------------------------------------------------
set instList [lsort -real -index 1 $instList]

# ---------------------------------------------------------
# 4. Get boundary values
# ---------------------------------------------------------
set minX [lindex [lindex $instList 0] 1]
set maxX [lindex [lindex $instList end] 1]

# ---------------------------------------------------------
# 5. Apply abutment rules on edge instances
# ---------------------------------------------------------
foreach inst $instList {

    set ref [lindex $inst 0]
    set x   [lindex $inst 1]

    if {$x == $minX} {
        db::setAttr leftAbut -of $ref -value false
    }

    if {$x == $maxX} {
        db::setAttr rightAbut -of $ref -value false
    }
}

# ---------------------------------------------------------
# 6. Completion message
# ---------------------------------------------------------
puts "Sorted edge abutment fix completed successfully."