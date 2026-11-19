# =========================================================
# Script: Global Edge Abutment Fix
# =========================================================

# Description:
# This script detects boundary instances in the full layout
# by calculating global minimum and maximum X coordinates.
# It disables left and right abutment only for edge devices.

# Use case:
# - Fix boundary connectivity issues in full-chip layout
# - Prevent incorrect abutment at chip edges

# =========================================================

# ---------------------------------------------------------
# 1. Get current design
# ---------------------------------------------------------
set design [ed]

# ---------------------------------------------------------
# 2. Initialize instance list and boundary values
# ---------------------------------------------------------
set instList {}
set minX 1e9
set maxX -1e9

# ---------------------------------------------------------
# 3. Collect instances and compute X boundaries
# ---------------------------------------------------------
db::foreach i [db::getInsts -of $design] {

    set bb [db::getAttr bBox -of $i]
    set x0 [lindex [lindex $bb 0] 0]

    lappend instList [list $i $x0]

    if {$x0 < $minX} { set minX $x0 }
    if {$x0 > $maxX} { set maxX $x0 }
}

# ---------------------------------------------------------
# 4. Apply abutment rule only to edge instances
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
# 5. Completion message
# ---------------------------------------------------------
puts "Global edge abutment fix applied successfully."