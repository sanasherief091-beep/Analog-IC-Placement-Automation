# =========================================================
# Script: Update MOSFET Finger Count (NF) in Layout Database
# =========================================================

# Description:
# This script updates the NF (number of fingers) attribute
# for all instances in the currently opened design.
# It retrieves the active design, loops over all instances,
# and assigns a fixed NF value to each device.

# Use case:
# - Standardizing device fingers across the layout
# - Pre-layout or post-placement parameter adjustment
# - Ensuring consistency in physical design parameters

# =========================================================

# ------------------------------
# 1. Set target NF value
# ------------------------------
set nf 2

# ------------------------------
# 2. Get active design
# ------------------------------
set design [ed]

# ------------------------------
# 3. Get all instances in design
# ------------------------------
set insts [db::getAttr insts -of $design]

# ------------------------------
# 4. Update NF for all instances
# ------------------------------
db::foreach inst $insts {
    db::setAttr nf -of $inst -value $nf
}

# ------------------------------
# 5. Completion message
# ------------------------------
puts "NF update completed successfully. All devices set to NF = $nf"