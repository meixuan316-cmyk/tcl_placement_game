This project is a simple APR (Automatic Placement and Routing) placement game implemented in Tcl.

## Overview
This project simulates a simplified chip placement environment, where users can place macros on a grid and evaluate placement quality based on wirelength and congestion.

It is designed to demonstrate fundamental concepts in physical design and scripting ability using Tcl.

---

## Features
- Grid-based macro placement
- Boundary checking to ensure valid placement
- Overlap detection between macros
- Wirelength estimation using Manhattan distance
- Simple congestion-aware scoring system

---

## Concepts Demonstrated
- Basic APR (Automatic Placement and Routing) flow concepts
- Macro placement strategy
- Wirelength optimization (HPWL approximation)
- Congestion awareness
- Tcl scripting and logic design

---

## How to Run

```bash
tclsh apr_placement_game.tcl
