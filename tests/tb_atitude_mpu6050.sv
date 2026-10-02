`timescale 1ns/1ps
module tb_atitude_mpu6050;
    logic clk=0;
    always #5 clk=~clk;
    logic ok=1, valid=0;
    logic signed [15:0] ax=0,ay=0,az=16384,gx=0,gy=0,gz=0;
    wire cal,ready,fresh;
    wire signed [10:0] pitch;
    wire signed [9:0] roll;
    atitude_mpu6050 #(.TIMEOUT_CYCLES(1000)) dut(
        clk,ok,valid,ax,ay,az,gx,gy,gz,cal,ready,fresh,pitch,roll);
    task sample(input integer x,y,z);
        @(negedge clk); ax=16'(x);ay=16'(y);az=16'(z);valid=1;
        @(negedge clk);valid=0;
        repeat(60) @(negedge clk);
    endtask
    task check(input integer ep,er,tolerance);
        if(pitch<ep-tolerance || pitch>ep+tolerance || roll<er-tolerance || roll>er+tolerance)
            $fatal(1,"Entrada=%0d,%0d,%0d obtido=%0d,%0d esperado=%0d,%0d (+/-%0d)",ax,ay,az,pitch,roll,ep,er,tolerance);
    endtask
    initial begin
        gx=1000;
        repeat(6) sample(0,0,16384);
        if(cal) $fatal(1,"Em movimento: calibrado=1 esperado=0");
        gx=0;
        sample(0,0,16384);sample(1024,0,16384);
        if(dut.cal_count != 0) $fatal(1,"Salto durante calibracao: contador esperado=0");
        repeat(64) sample(1024,-512,16384);
        if(!cal || !ready) $fatal(1,"Calibracao parada: esperado pronto");
        check(0,0,0);
        repeat(32) sample(5120,-512,16384);
        check(40,0,1);
        repeat(32) sample(1024,3584,16384);
        check(0,64,1);
        repeat(32) sample(5120,3584,16384);
        check(40,64,1);
        repeat(32) sample(-3072,-4608,16384);
        check(-40,-64,1);
        repeat(32) sample(32767,32767,8192);
        check(80,128,0);
        repeat(32) sample(-32768,-32768,8192);
        check(-80,-128,0);
        sample(0,0,0);
        if(ready) $fatal(1,"Z=0: pronto esperado=0");
        check(-80,-128,0);
        sample(0,0,-16384);
        if(ready) $fatal(1,"Invertido: pronto esperado=0");
        ok=0;repeat(2) @(negedge clk);
        if(cal || ready) $fatal(1,"Desconectado: status esperado=0");
        check(-80,-128,0);
        ok=1;
        repeat(64) sample(0,0,16384);
        check(0,0,0);
        if(!ready) $fatal(1,"Reconexao: esperado recalibrado");
        repeat(1100) @(negedge clk);
        if(cal || ready) $fatal(1,"Sem amostras: esperado timeout");
        $display("PASS atitude MPU6050: calibracao, movimento, sinais, saturacao, Z invalido, desconexao e timeout");
        $finish;
    end
    initial begin #1000000; $fatal(1,"Timeout atitude"); end
endmodule
