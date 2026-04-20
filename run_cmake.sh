#!/bin/bash

# Set CMake path
export PATH="/home/embedfire/QtProject/EnviroTrend_demo-main/cmake-3.28.0-linux-x86_64/bin:$PATH"

# Run CMake command with provided arguments
cmake "$@"
