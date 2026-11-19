# ==============================================================================
# TCL Script: Dynamic POCUT Generation with Insets
#
# Purpose:
# This script automatically generates POCUT rectangles across the layout
# based on the design bounding box and device height.
#
# Key Logic:
# 1. Calculates number of rows using total height / device height.
# 2. Applies horizontal insets to avoid edge overlap.
# 3. Places cuts with precise Y-step increments to avoid drift.
# 4. Generates uniform POCUT rectangles across the full design.
# ==============================================================================


# ==============================================================================
# 1. Initialize Design Context
# ==============================================================================
set design [ed]


# ==============================================================================
# 2. Extract Design Bounding Box
# ==============================================================================
set fullBBox [db::getAttr bBox -of $design]

set x_min [lindex [lindex $fullBBox 0] 0]
set y_min [lindex [lindex $fullBBox 0] 1]
set x_max [lindex [lindex $fullBBox 1] 0]
set y_max [lindex [lindex $fullBBox 1] 1]


# ==============================================================================
# 3. User Parameters
# ==============================================================================
set devHeight    0.568
set cutThickness 0.04
set inset        0.08
set lpp          {POCUT drawing}


# ==============================================================================
# 4. Compute Layout Dimensions
# ==============================================================================
set totalHeight [expr $y_max - $y_min]
set rowCount    [expr int($totalHeight / $devHeight)]


# ==============================================================================
# 5. Apply Horizontal Insets
# ==============================================================================
set x_start [expr $x_min + $inset]
set x_end   [expr $x_max - $inset]

puts "LOG: Detected Height = $totalHeight | Rows = $rowCount"
puts "LOG: Width adjusted by inset = $inset (X: $x_start → $x_end)"


# ==============================================================================
# 6. Generate POCUTs Row by Row
# ==============================================================================
for {set i 0} {$i < $rowCount} {incr i} {

    # Compute Y position using fixed step increment
    set offset   [expr $i * $devHeight]
    set currentY [expr $y_min + $devHeight + $offset]

    # Prevent exceeding top boundary
    if {$currentY > [expr $y_max - 0.1]} {
        puts "LOG: Skipping top boundary at Y = $currentY"
        break
    }

    # Format coordinate for precision stability
    set currentY [format "%.3f" $currentY]

    # Define rectangle boundaries
    set y1 [expr $currentY - ($cutThickness / 2.0)]
    set y2 [expr $currentY + ($cutThickness / 2.0)]

    set rectBox [list [list $x_start $y1] [list $x_end $y2]]

    # Create POCUT rectangle
    le::createRectangle $rectBox \
        -design $design \
        -lpp $lpp

    puts "SUCCESS: POCUT created at Y = $currentY"
}

puts "--- DYNAMIC POCUT GENERATION COMPLETED SUCCESSFULLY ---"