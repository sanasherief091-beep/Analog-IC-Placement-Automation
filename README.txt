==============================================================================
AUTOMATIC ANALOG IC PLACEMENT GENERATION SYSTEM
==============================================================================

PROJECT OVERVIEW:
-----------------
This project implements an automated analog IC placement generation flow
starting from a SPICE-like netlist (Python stage) and producing a structured
placement pattern used in physical design tools (TCL stage).

The system focuses ONLY on placement generation and supporting physical
pre-processing steps such as abutment control, dummy handling, TAP insertion,
and cut-layer generation (POCUT).

The main goal is to generate:
- Symmetric device placement
- Balanced row/column distribution
- Layout-ready placement pattern
- Physical design preparation steps


==============================================================================


========================
PART 1: PYTHON FLOW (PLACEMENT GENERATION)
========================

PHASE 0: NETLIST PARSING
------------------------
- Reads SPICE-like netlist file
- Extracts MOSFET devices
- Stores device parameters:
    * Drain (D), Gate (G), Source (S), Bulk (B)
    * Model type
    * Multiplicity (M)
    * Finger count (NF)

OUTPUT:
- Structured device database


PHASE 1: CIRCUIT DETECTION
--------------------------
- Identifies circuit topology:

1. Current Mirror:
   - Same Gate and Source connections

2. Differential Pair:
   - Same Source node + same MOS model

3. Single Device:
   - No matching circuit relationship

OUTPUT:
- Grouped placement blocks


PHASE 2: STRATEGY ASSIGNMENT
----------------------------
- Assigns placement strategy per group:

    INTER   → Differential Pair
    COMMON  → Current Mirror
    SINGLE  → Independent device

- Adjusts strategy based on interconnections between groups


PHASE 3: COLUMN CALCULATION
--------------------------
- Computes minimum required columns
- Based on critical device multiplicity (M)
- Ensures balanced placement distribution


PHASE 4: PATTERN GENERATION
--------------------------
- Converts grouped devices into placement matrix
- Builds row-based structure using:
    * Total multiplicity
    * Column constraints

- Ensures:
    * Symmetry-aware placement
    * Balanced row filling
    * Proper repetition handling
    * Center padding using dummy cells

OUTPUT FILE:
1. placement_pattern.txt
   - Machine-readable placement pattern

2. layout_report.txt
   - Human-readable analysis report


==============================================================================


========================
PART 2: TCL FLOW (PLACEMENT IMPLEMENTATION SUPPORT)
========================

PHASE 5: NF UPDATE
------------------
- Updates all MOS devices:
    NF = 2
- Ensures uniform device configuration


PHASE 6: EDGE ABUTMENT CONTROL
------------------------------
- Extracts all instances from design
- Determines leftmost and rightmost boundaries using X-coordinates

Rules:
    Left edge  → leftAbut = FALSE
    Right edge → rightAbut = FALSE
    Middle     → leftAbut = TRUE, rightAbut = TRUE

- Ensures proper edge tiling and placement continuity


PHASE 7: DUMMY DEVICE TIE-OFF
-----------------------------
- Targets only dummy devices (lxDummy*)
- Extracts Source net (S)

Connections:
    Drain (D) → Source net
    Gate  (G) → Source net

PURPOSE:
- Prevent floating nodes
- Ensure electrical consistency of dummy devices
- Maintain placement integrity


PHASE 8: POCUT GENERATION
-------------------------
- Reads design bounding box
- Computes:
    * Total height
    * Number of rows dynamically

- Generates horizontal cut layers (POCUT) using:
    * Fixed cut thickness = 0.04 µm
    * Inset margin = 0.08 µm

PURPOSE:
- Define placement cut boundaries
- Improve row segmentation consistency


PHASE 9: TAP ROW GENERATION
--------------------------
- Computes placement width and column count

Places:
1. START TAPS:
   - Ntap_start
   - Ptap_start

2. REPEATED ROW TAPS:
   - Ntap_row_i
   - Ptap_row_i

3. END TAPS:
   - Ntap_end
   - Ptap_end

PARAMETERS:
- Step spacing = 0.074 µm
- Alignment based on design bounding box

PURPOSE:
- Provide substrate/well connectivity
- Ensure analog reliability rules
- Support process compliance


==============================================================================


KEY FEATURES
------------
- Fully automated placement generation
- Symmetry-aware device distribution
- Dynamic row/column calculation
- Dummy-aware electrical handling
- Edge-safe abutment control
- Physical design preparation support


==============================================================================


FINAL OUTPUT
-------------
The system generates a:

✔ Structured placement pattern
✔ Symmetric device distribution
✔ Layout-tool compatible pattern file
✔ Physically aware analog placement floorplan input


==============================================================================


AUTHOR
------
Sana Sherief