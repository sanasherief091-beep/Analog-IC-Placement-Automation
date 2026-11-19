# Automated Analog IC Placement Generation System

## Project Overview

This project presents an automated framework for generating placement patterns for analog integrated circuits, starting from a SPICE-like netlist and producing a structured placement configuration for physical design implementation.

The system combines Python-based placement generation with TCL-based physical design automation to support symmetry-aware device distribution and essential layout preparation operations.

The framework focuses on automating intra-cell placement and supporting physical preprocessing tasks.

## Project Workflow

The framework consists of two main stages:

### 1. Python-Based Placement Generation

The Python flow processes the input netlist and generates a structured placement pattern through the following phases:

**Netlist Parsing**
- Reads a SPICE-like netlist.
- Extracts MOSFET device information, including D, G, S, and B terminals.
- Identifies model type, multiplicity (M), and finger count (NF).

**Circuit Topology Detection**
- Identifies Current Mirror structures.
- Detects Differential Pair configurations.
- Classifies independent devices.

**Placement Strategy Assignment**
- Assigns appropriate placement strategies based on circuit topology:
  - COMMON: Current Mirror
  - INTER: Differential Pair
  - SINGLE: Independent devices

**Column Calculation**
- Determines the minimum required number of columns based on device multiplicity.
- Supports balanced placement distribution.

**Placement Pattern Generation**
- Converts grouped devices into a structured placement matrix.
- Applies symmetry-aware distribution.
- Balances row filling and device repetition.
- Uses dummy cells for center padding when required.

**Generated Outputs:**
- `placement_pattern.txt`: Machine-readable placement configuration.
- `layout_report.txt`: Human-readable placement analysis report.

### 2. TCL-Based Physical Design Automation

The TCL flow performs supporting physical design preparation operations:

**NF Update**
- Updates MOS device finger configuration to NF = 2.

**Edge Abutment Control**
- Identifies leftmost and rightmost instances using their X-coordinates.
- Configures edge abutment properties to support proper placement continuity.

**Dummy Device Tie-Off**
- Identifies dummy devices.
- Connects their Drain and Gate terminals to their Source net to prevent floating nodes.

**POCUT Generation**
- Calculates the design bounding box and row distribution.
- Generates horizontal POCUT layers using defined geometric parameters.

**Tap Row Generation**
- Calculates placement dimensions and column distribution.
- Generates start, repeated, and end tap structures.
- Supports substrate and well connectivity requirements.

## Key Features

- Automated analog device placement generation.
- Symmetry-aware placement strategies.
- Current Mirror and Differential Pair recognition.
- Dynamic row and column calculation.
- Dummy device handling.
- Automated edge abutment configuration.
- POCUT layer generation.
- Automated tap row insertion.
- Python and TCL integration for physical design preparation.

## Technologies & Tools

- Python
- TCL Scripting
- Synopsys Custom Compiler
- Analog IC Layout Design
- SPICE-like Netlists
- Physical Design Automation

## Project Structure

```text
Analog-IC-Placement-Automation/
│
├── Documentation/
│
├── Screenshots/
│
├── Results/
│
└── README.md
```

## Project Scope

The framework focuses on automated analog IC placement generation and supporting physical preprocessing operations.

It does not implement a complete automated routing flow.

## Author

**Sana Sherief**

Electrical Engineering – Communications & Electronics