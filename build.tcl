#!/usr/bin/tclsh
# Build script for TN9K Space Invaders project

# Open project
open_project TN9K-Invaders.gprj

# Run synthesis
run syn

# Run place and route
run pnr

# Exit
exit