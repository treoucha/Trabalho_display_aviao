`timescale 1ns/1ps
module mpu6050_i2c_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    tri1 sda, scl;
    reg slave_sda_low = 0;
    reg slave_scl_low = 0;
    assign sda = slave_sda_low ? 1'b0 : 1'bz;
    assign scl = slave_scl_low ? 1'b0 : 1'bz;
    wire [7:0] who_am_i;
    wire sensor_ok, amostra_valida;
    integer published = 0;
    reg previous_valid = 0;
    reg [95:0] previous_axes = 0;
    always @(negedge clk) begin
        if (amostra_valida) begin
            if (previous_valid || !sensor_ok)
                $fatal(1,"Amostra: esperado pulso de um ciclo com sensor_ok");
            published = published + 1;
        end
        if ({ax,ay,az,gx,gy,gz} !== previous_axes && !amostra_valida)
            $fatal(1,"Eixos mudaram sem amostra_valida");
        previous_axes = {ax,ay,az,gx,gy,gz};
        previous_valid = amostra_valida;
    end
    wire signed [15:0] ax, ay, az, gx, gy, gz;
    // Acelera apenas a espera de partida; mantém os tempos elétricos I2C.
    localparam logic [15:0] STARTUP_TICKS = 400;
    mpu6050_i2c #(.STARTUP_TICKS(STARTUP_TICKS)) dut (
        .clk(clk), .i2c_sda(sda), .i2c_scl(scl),
        .who_am_i(who_am_i), .sensor_ok(sensor_ok), .amostra_valida(amostra_valida),
        .accel_x(ax), .accel_y(ay), .accel_z(az),
        .gyro_x(gx), .gyro_y(gy), .gyro_z(gz)
    );

    reg present = 0;
    reg [7:0] identity = 8'h68;
    reg nack_wake = 0;
    reg nack_register = 0;
    reg nack_read_address = 0;
    reg stretch = 0;
    reg awake = 0;
    reg [2:0] configured = 0;
    reg [7:0] registers [0:255];
    reg [7:0] addr, pointer, value;
    reg master_ack;
    integer i;
    integer starts = 0;
    integer bursts = 0;
    integer wakes = 0;
    integer identities = 0;
    integer marker;
    time wake_time;

    time scl_rise = 0;
    time scl_fall = 0;
    time start_time = 0;
    always @(negedge sda) begin
        if (scl === 1'b1) begin
            if (scl_rise != 0 && $time - scl_rise < 4700)
                $fatal(1, "Setup de START=%0t esperado>=4700 ns", $time - scl_rise);
            start_time = $time;
        end
    end
    always @(posedge scl) begin
        if (scl_fall != 0 && $time - scl_fall < 4700)
            $fatal(1, "SCL baixo=%0t esperado>=4700 ns", $time - scl_fall);
        scl_rise = $time;
    end
    always @(negedge scl) begin
        if (start_time != 0 && $time - start_time < 4000)
            $fatal(1, "Hold de START=%0t esperado>=4000 ns", $time - start_time);
        if (scl_rise != 0 && $time - scl_rise < 4000)
            $fatal(1, "SCL alto=%0t esperado>=4000 ns", $time - scl_rise);
        scl_fall = $time;
    end
    always @(posedge sda) begin
        if ($time != 0 && scl === 1'b1 && $time - scl_rise < 4000)
            $fatal(1, "Setup de STOP=%0t esperado>=4000 ns", $time - scl_rise);
    end

    task automatic receive_byte(output reg [7:0] data);
        integer bit_no;
        begin
            for (bit_no = 7; bit_no >= 0; bit_no = bit_no - 1) begin
                @(posedge scl);
                data[bit_no] = sda;
                @(negedge scl);
            end
        end
    endtask

    task automatic reply(input reg ack);
        begin
            #100 slave_sda_low = ack;
            @(posedge scl);
            @(negedge scl);
            #100 slave_sda_low = 0;
        end
    endtask

    task automatic send_byte(input reg [7:0] data, output reg ack);
        integer bit_no;
        begin
            for (bit_no = 7; bit_no >= 0; bit_no = bit_no - 1) begin
                #100 slave_sda_low = ~data[bit_no];
                // Alongamento de SCL no meio de cada byte recebido pela FPGA.
                if (stretch && bit_no == 3) begin
                    slave_scl_low = 1;
                    #17000 slave_scl_low = 0;
                end
                @(posedge scl);
                @(negedge scl);
            end
            #100 slave_sda_low = 0;
            @(posedge scl);
            ack = !sda;
            @(negedge scl);
        end
    endtask

    // Modelo do escravo dirigido somente pelos pinos, sem acessar a FSM.
    initial forever begin : sensor_transaction
        @(negedge sda);
        if (scl === 1'b1) begin
            starts = starts + 1;
            receive_byte(addr);
            if (!present) begin
                reply(0);
            end else begin
                if (addr[7:1] !== 7'h68)
                    $fatal(1, "Endereco obtido=%h esperado=68", addr[7:1]);
                if (!addr[0]) begin
                    reply(1);
                    receive_byte(pointer);
                    if (pointer != 8'h75 && pointer != 8'h6B && pointer != 8'h3B && pointer != 8'h1C && pointer != 8'h1B && pointer != 8'h1A)
                        $fatal(1, "Registrador inesperado=%h", pointer);
                    reply(!nack_register);
                    if (!nack_register && (pointer == 8'h6B || pointer == 8'h1C || pointer == 8'h1B || pointer == 8'h1A)) begin
                        receive_byte(value);
                        if (value !== ((pointer == 8'h1A) ? 8'h03 : 8'h00))
                            $fatal(1, "Registrador=%h obtido=%h esperado=%h", pointer,value,((pointer == 8'h1A) ? 8'h03 : 8'h00));
                        reply(!nack_wake);
                        if (!nack_wake) begin
                            case (pointer)
                                8'h1C: configured[0] = 1;
                                8'h1B: configured[1] = 1;
                                8'h1A: configured[2] = 1;
                            endcase
                        end
                        if (!nack_wake && pointer == 8'h6B) begin
                            configured = 0;
                            awake = 1;
                            wakes = wakes + 1;
                            wake_time = $time;
                        end
                    end
                end else begin
                    reply(!nack_read_address);
                    if (!nack_read_address) begin
                        if (pointer == 8'h75) begin
                            send_byte(identity, master_ack);
                            if (master_ack !== 0)
                                $fatal(1, "WHO_AM_I: resposta obtida=ACK esperada=NACK");
                            identities = identities + 1;
                        end else if (pointer == 8'h3B) begin
                            if (!awake || configured != 3'b111 || $time - wake_time < STARTUP_TICKS * 2500)
                                $fatal(1, "Leitura antes da inicializacao ou espera de partida");
                            for (i = 0; i < 14; i = i + 1) begin
                                send_byte(registers[8'h3B+i], master_ack);
                                if (master_ack !== (i < 13))
                                    $fatal(1, "Byte=%0d ACK obtido=%b esperado=%b", i, master_ack, (i < 13));
                            end
                            bursts = bursts + 1;
                        end else
                            $fatal(1, "Leitura inesperada em %h", pointer);
                    end
                end
            end
        end
    end

    task automatic check_axes(
        input signed [15:0] ex_ax, ex_ay, ex_az, ex_gx, ex_gy, ex_gz
    );
        begin
            if (ax !== ex_ax || ay !== ex_ay || az !== ex_az ||
                gx !== ex_gx || gy !== ex_gy || gz !== ex_gz)
                $fatal(1, "Eixos obtidos=%0d,%0d,%0d,%0d,%0d,%0d esperados=%0d,%0d,%0d,%0d,%0d,%0d",
                    ax, ay, az, gx, gy, gz, ex_ax, ex_ay, ex_az, ex_gx, ex_gy, ex_gz);
        end
    endtask

    initial begin
        {registers['h3B], registers['h3C]} = 16'h1234;
        {registers['h3D], registers['h3E]} = 16'hFEDC;
        {registers['h3F], registers['h40]} = 16'h8000;
        {registers['h41], registers['h42]} = 16'hA55A; // Temperatura descartada.
        {registers['h43], registers['h44]} = 16'h7FFF;
        {registers['h45], registers['h46]} = 16'hFFFF;
        {registers['h47], registers['h48]} = 16'h0102;

        #25000000;
        if (sensor_ok !== 0 || starts < 2)
            $fatal(1, "Sensor ausente: status=%b tentativas=%0d", sensor_ok, starts);
        check_axes(0, 0, 0, 0, 0, 0);
        $display("PASS sensor ausente: sensor_ok=0, novas tentativas");

        identity = 8'h70;
        present = 1;
        wait (who_am_i == 8'h70);
        #100000;
        if (sensor_ok !== 0 || wakes != 0)
            $fatal(1, "ID incorreto: status=%b inicializacoes=%0d", sensor_ok, wakes);
        $display("PASS WHO_AM_I=70: sensor_ok=0, sem inicializacao");

        identity = 8'h68;
        nack_wake = 1;
        #35000000;
        if (sensor_ok !== 0 || wakes != 0)
            $fatal(1, "NACK em PWR_MGMT_1: status=%b inicializacoes=%0d", sensor_ok, wakes);
        $display("PASS NACK em PWR_MGMT_1: sensor_ok=0");

        nack_wake = 0;
        stretch = 1;
        wait (sensor_ok);
        check_axes(4660, -292, -32768, 32767, -1, 258);
        $display("PASS leitura com clock stretching: eixos=4660,-292,-32768,32767,-1,258");

        marker = bursts;
        {registers['h3B], registers['h3C]} = 16'hFFFF;
        {registers['h47], registers['h48]} = 16'h8000;
        wait (bursts > marker);
        // O driver só publica os eixos após STOP.
        check_axes(4660, -292, -32768, 32767, -1, 258);
        #50000;
        check_axes(-1, -292, -32768, 32767, -1, -32768);
        $display("PASS segunda amostra: eixos publicados juntos apos STOP");

        nack_register = 1;
        wait (!sensor_ok);
        check_axes(-1, -292, -32768, 32767, -1, -32768);
        #1000000;
        nack_register = 0;
        wait (sensor_ok);
        $display("PASS NACK de registrador: invalida status, preserva eixos e recupera");

        nack_read_address = 1;
        wait (!sensor_ok);
        #1000000;
        nack_read_address = 0;
        wait (sensor_ok);
        $display("PASS NACK de endereco de leitura: recupera");

        present = 0;
        wait (!sensor_ok);
        marker = published;
        #15000000;
        if (published != marker) $fatal(1,"Desconectado: publicou amostra");
        present = 1;
        wait (sensor_ok);
        $display("PASS desconexao: sem amostras falsas e recuperacao");

        // Prende SCL entre transações: o timeout deve invalidar a amostra.
        @(negedge scl);
        slave_scl_low = 1;
        #12000000;
        if (sensor_ok !== 0)
            $fatal(1, "SCL preso: status obtido=%b esperado=0", sensor_ok);
        disable sensor_transaction;
        slave_sda_low = 0;
        slave_scl_low = 0;
        $display("PASS SCL preso: sensor_ok=0 apos timeout");
        wait (sensor_ok);
        check_axes(-1, -292, -32768, 32767, -1, -32768);
        $display("PASS recuperacao apos liberar SCL");
        $display("PASS todos os testes");
        $finish;
    end

    initial begin
        #1000000000;
        $fatal(1, "Timeout global da simulacao");
    end
endmodule
