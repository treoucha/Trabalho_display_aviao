#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
for test in reticula controle_heading horizonte atitude entrada_hud dados_hud numeros roll modo vga modos; do
    iverilog -g2012 -s "tb_$test" -o "build/tests/$test" rtl/*.sv "tests/tb_$test.sv"
    vvp "build/tests/$test"
done
