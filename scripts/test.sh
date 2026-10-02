#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
for test in atitude_mpu6050 sensor_hud reticula controle_heading horizonte atitude entrada_hud dados_hud numeros roll modo vga modos; do
    iverilog -g2012 -s "tb_$test" -o "build/tests/$test" rtl/*.sv "tests/tb_$test.sv"
    vvp -i "build/tests/$test"
done

iverilog -g2012 -s mpu6050_i2c_tb -o build/tests/mpu6050 rtl/mpu6050_i2c.sv tests/mpu6050_i2c_tb.sv
vvp -i build/tests/mpu6050
