"""
=========================================================
Project: Automatic Analog IC Layout Generator
=========================================================

Description:
This project implements an automated analog IC placement
generation flow starting from a SPICE netlist.

The system detects analog circuit structures, assigns
placement strategies, and generates a balanced layout matrix
suitable for physical design automation.

The algorithm ensures even device distribution across all 
assigned rows to maintain a symmetrical rectangular aspect ratio.

Main Features:
- SPICE netlist parsing (MOSFET extraction)
- Circuit topology detection (Diff-Pair, Current Mirror)
- Automatic strategy assignment (INTER / COMMON / SINGLE)
- Balanced row-based placement (Even unit distribution)
- Centered layout padding using dummy 'e' cells
- Pattern and analysis report export

Author: Sana Sherief
"""

import math
import re

# =========================================================
# PHASE 0: NETLIST PARSING
# =========================================================
def parse_netlist(file_path):
    """
    Parses a SPICE netlist to extract MOSFET instances, their 
    connectivity (D, G, S, B), and parameters (m, nf).
    """
    mos_list = []

    try:
        with open(file_path, "r") as f:
            for line in f:
                line = line.strip()

                # Ignore comments (*) and SPICE commands (.)
                if not line or line.startswith(("*", ".")):
                    continue

                # Identify MOSFET definitions (starting with M)
                if line.upper().startswith("M"):
                    tokens = line.split()
                    params = {}

                    # Extract parameters formatted as key=value (e.g., m=16)
                    for t in tokens:
                        if '=' in t:
                            key, value = t.split('=')
                            params[key.lower()] = value

                    mos_list.append({
                        "name": tokens[0],
                        "D": tokens[1].upper(),
                        "G": tokens[2].upper(),
                        "S": tokens[3].upper(),
                        "B": tokens[4].upper(),
                        "model": tokens[5],
                        "m": int(params.get("m", 1)),
                        "nf": int(params.get("nf", 1))
                    })

    except Exception as e:
        print(f"Error during netlist parsing: {e}")

    return mos_list


# =========================================================
# PHASE 1: CIRCUIT DETECTION
# =========================================================
def phase1_detection(mos_list):
    """
    Detects circuit structures (Current Mirrors and Differential Pairs)
    based on shared nodes and model matching.
    """
    groups = []
    assigned = set()

    # Detect Current Mirrors (Shared Gate and Shared Source)
    for i, m1 in enumerate(mos_list):
        if m1["name"] in assigned:
            continue

        mirror = [m1]
        for m2 in mos_list[i+1:]:
            if (m2["name"] not in assigned and
                m1["G"] == m2["G"] and
                m1["S"] == m2["S"]):
                mirror.append(m2)

        if len(mirror) > 1:
            groups.append({
                "type": "Current Mirror",
                "devices": mirror,
                "reason": "Matched gate and source connections"
            })
            assigned.update([d["name"] for d in mirror])

    # Detect Differential Pairs (Shared Source and Same Model)
    for i, m1 in enumerate(mos_list):
        if m1["name"] in assigned:
            continue

        for m2 in mos_list[i+1:]:
            if (m2["name"] not in assigned and
                m1["S"] == m2["S"] and
                m1["model"] == m2["model"]):

                groups.append({
                    "type": "Differential Pair",
                    "devices": [m1, m2],
                    "reason": "Common-source topology match"
                })
                assigned.update([m1["name"], m2["name"]])
                break

    # Treat remaining devices as standalone instances
    for m in mos_list:
        if m["name"] not in assigned:
            groups.append({
                "type": "Single Device",
                "devices": [m],
                "reason": "No matching circuit topology"
            })

    return groups


# =========================================================
# PHASE 2: STRATEGY ASSIGNMENT
# =========================================================
def phase2_strategy(groups):
    """
    Assigns placement strategies (INTER, COMMON, or SINGLE).
    Forces INTER strategy for mirrors connected to differential pairs.
    """
    for g in groups:
        if g["type"] == "Differential Pair":
            g["strategy"] = "INTER"
        elif g["type"] == "Current Mirror":
            g["strategy"] = "COMMON"
        else:
            g["strategy"] = "SINGLE"

    # Strategy Override: Switch connected mirrors to INTER strategy for better matching
    for g_diff in groups:
        if g_diff["type"] == "Differential Pair":
            diff_nodes = [d["S"] for d in g_diff["devices"]] + \
                         [d["D"] for d in g_diff["devices"]]

            for gm in groups:
                if gm["type"] == "Current Mirror":
                    mirror_nodes = [d["D"] for d in gm["devices"]]
                    if any(node in diff_nodes for node in mirror_nodes):
                        gm["strategy"] = "INTER"
                        gm["reason"] = "Connected to differential pair"

    return groups


# =========================================================
# HELPER: COLUMN CALCULATION
# =========================================================
def calculate_cols_from_min_m(mos_list):
    """
    Calculates the layout column count based on the minimum 
    multiplicity (m) of matched circuit devices.
    """
    critical_m = []

    for i, m1 in enumerate(mos_list):
        for m2 in mos_list[i+1:]:
            # Check matching conditions for diff-pairs and mirrors
            if (m1["S"] == m2["S"] and m1["model"] == m2["model"]) or \
               (m1["G"] == m2["G"] and m1["S"] == m2["S"]):
                critical_m.extend([m1["m"], m2["m"]])

    if not critical_m:
        return min(m["m"] for m in mos_list)

    return min(critical_m)


# =========================================================
# PHASE 3: BALANCED PATTERN GENERATION
# =========================================================
def phase3_pattern_gen(groups, mos_list):
    """
    Core algorithm to generate the placement matrix. Ensures even distribution
    across all rows for a symmetrical rectangular layout.
    """
    cols = calculate_cols_from_min_m(mos_list)

    def extract_number(name):
        # Extracts ID from names like 'MM12' -> 12
        match = re.search(r"\d+", name)
        return int(match.group()) if match else 0

    # Assign a unique character (A, B, C...) to each netlist device
    sorted_mos_list = sorted(mos_list, key=lambda x: extract_number(x["name"]))
    name_to_char = {m["name"]: chr(65 + i) for i, m in enumerate(sorted_mos_list)}

    final_results = []

    for g in groups:
        remaining_m = {name_to_char[d["name"]]: d["m"] for d in g["devices"]}
        total_m = sum(remaining_m.values())
        
        # Calculate total rows required
        num_rows = math.ceil(total_m / cols)
        
        # Balanced Distribution Logic:
        # Splits the total units evenly across the calculated rows.
        base_per_row = total_m // num_rows
        extra_units = total_m % num_rows

        sorted_devices = sorted(g["devices"], key=lambda x: x["m"], reverse=True)
        chars_sorted = [name_to_char[d["name"]] for d in sorted_devices]

        matrix = []
        last_char = "" 

        for r in range(num_rows):
            # Assign the target unit count for the current row
            current_row_slots = base_per_row + (1 if r < extra_units else 0)
            row_content = []

            # ---------------- INTER strategy ----------------
            if g["strategy"] == "INTER":
                for _ in range(current_row_slots):
                    available = [c for c in chars_sorted if remaining_m[c] > 0]
                    if not available: break
                    
                    # Alternate characters to ensure interdigitation
                    next_char = available[0]
                    if len(available) > 1 and available[0] == last_char:
                        next_char = available[1]
                    
                    row_content.append(next_char)
                    remaining_m[next_char] -= 1
                    last_char = next_char
                row_str = "".join(row_content)

            # ---------------- COMMON strategy ----------------
            elif g["strategy"] == "COMMON" and len(chars_sorted) >= 2:
                left_side = ""
                center_char = chars_sorted[-1]
                
                for c in chars_sorted[:-1]:
                    # Determine units for this row based on the device's proportional share
                    share = (d["m"] for d in g["devices"] if name_to_char[d["name"]] == c).__next__() // num_rows
                    count_to_take = min(remaining_m[c] // 2, share // 2)
                    left_side += c * count_to_take
                    remaining_m[c] -= count_to_take * 2
                
                # Fill the center with the last device type
                center_capacity = current_row_slots - (len(left_side) * 2)
                center_count = min(remaining_m[center_char], max(0, center_capacity))
                remaining_m[center_char] -= center_count
                row_str = left_side + (center_char * center_count) + left_side[::-1]
            
            # ---------------- SINGLE strategy ----------------
            else:
                c = chars_sorted[0]
                count = min(remaining_m[c], current_row_slots)
                row_str = c * count
                remaining_m[c] -= count

            # Padding logic: Equalize row width using dummy 'e' cells for centering
            pad = cols - len(row_str)
            left_pad = pad // 2
            right_pad = pad - left_pad
            final_row = "e" * left_pad + row_str + "e" * right_pad
            matrix.append(final_row)

        final_results.append({
            "devices": g["devices"], "type": g["type"], "strategy": g["strategy"],
            "reason": g["reason"], "matrix": matrix, "rows": len(matrix), "cols": cols
        })

    return final_results, cols


# =========================================================
# PHASE 4: IMPROVED EXPORT & REPORTING
# =========================================================
def phase4_export(results, cols, mos_list):
    """
    Exports the placement pattern and a detailed, user-friendly 
    analysis report with legends and statistics.
    """
    # 1. Prepare machine-readable pattern
    all_blocks = [row for r in results for row in r["matrix"] if row.strip()]

    with open("placement_pattern.txt", "w") as f:
        f.write("pattern=" + " ".join(all_blocks) + "\n")
        f.write(f"columns={cols}\n")
        f.write("repeatY=1\n")

    # 2. Prepare user-friendly report
    with open("layout_report.txt", "w") as f:
        f.write("=" * 80 + "\n")
        f.write("AUTOMATED ANALOG IC LAYOUT REPORT\n")
        f.write("=" * 80 + "\n\n")

        # --- SECTION: OVERALL SUMMARY ---
        f.write("[1] DESIGN SUMMARY\n")
        f.write(f"Total Columns:    {cols}\n")
        f.write(f"Total Devices:    {len(mos_list)}\n")
        f.write(f"Total Blocks:     {len(results)}\n")
        f.write(f"Total Rows:       {len(all_blocks)}\n\n")

        # --- SECTION: CHARACTER LEGEND ---
        # Re-generating the mapping to display it in the report
        def extract_number(name):
            match = re.search(r"\d+", name)
            return int(match.group()) if match else 0
        
        sorted_mos = sorted(mos_list, key=lambda x: extract_number(x["name"]))
        f.write("[2] CHARACTER LEGEND (Mapping)\n")
        f.write(f"{'Char':<6} | {'Device Name':<12} | {'Model':<10} | {'M-Factor':<8}\n")
        f.write("-" * 50 + "\n")
        for i, m in enumerate(sorted_mos):
            char = chr(65 + i)
            f.write(f"{char:<6} | {m['name']:<12} | {m['model']:<10} | {m['m']:<8}\n")
        f.write(f"{'e':<6} | {'Dummy Cell':<12} | {'N/A':<10} | {'N/A':<8}\n\n")

        # --- SECTION: PLACEMENT DETAILS ---
        f.write("[3] PLACEMENT BLOCK DETAILS\n")
        for idx, r in enumerate(results):
            f.write(f"BLOCK {idx+1}: {r['type']}\n")
            f.write(f"  - Devices:  {', '.join([d['name'] for d in r['devices']])}\n")
            f.write(f"  - Strategy: {r['strategy']}\n")
            f.write(f"  - Logic:    {r['reason']}\n")
            f.write(f"  - Grid:     {r['rows']} Rows x {r['cols']} Columns\n")
            f.write(f"  - Matrix Visualization:\n")
            
            # Draw a simple box around the matrix
            f.write("    " + "+" + "-" * (r['cols'] + 2) + "+" + "\n")
            for row in r["matrix"]:
                f.write(f"    | {row} |\n")
            f.write("    " + "+" + "-" * (r['cols'] + 2) + "+" + "\n")
            f.write("\n" + "-" * 50 + "\n\n")

        f.write("End of Report.\n")

# =========================================================
# MAIN EXECUTION
# =========================================================
if __name__ == "__main__":
    netlist_path = "GP_ota_final_placement.sp"

    # Start generation flow
    devices = parse_netlist(netlist_path)

    if devices:
        # Detect circuits
        groups = phase1_detection(devices)
        
        # Assign strategies
        groups = phase2_strategy(groups)
        
        # Generate patterns (Balanced rows)
        results, cols = phase3_pattern_gen(groups, devices)
        
        # Export with improved report
        phase4_export(results, cols, devices)

        print("-" * 50)
        print(f"SUCCESS: Placement files generated.")
        print(f"Columns: {cols}")
        print(f"Check 'layout_report.txt' for the Character Legend.")
        print("-" * 50)