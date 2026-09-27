`timescale 1ns/1ps
module tb_entrada_hud;
    logic origem=0,destino=0,valido=0;
    always #5 origem=~origem;
    always #20 destino=~destino;
    logic [47:0] dados=0;
    wire pronto,validade;
    wire [47:0] recebido;
    entrada_hud dut(origem,destino,valido,dados,pronto,validade,recebido);
    integer quantidade=0;
    logic [47:0] esperado;
    always @(negedge destino) begin
        if(validade) begin
            if(recebido !== esperado) $fatal(1,"Amostra recebida=%h esperada=%h",recebido,esperado);
            quantidade++;
        end
    end
    initial begin
        for(int n=0;n<16;n++) begin
            wait(pronto); @(negedge origem);
            esperado={16'(n),16'(~n),16'(n*13)};
            dados=esperado; valido=1;
            @(negedge origem); valido=0; dados='1;
            wait(pronto); repeat(2) @(negedge destino);
            if(quantidade!=n+1) $fatal(1,"Entrega ausente ou duplicada");
        end
        $display("PASS entrada: 16 amostras atômicas de 100 para 25 MHz, sem duplicação"); $finish;
    end
    initial begin #100000; $fatal(1,"Timeout da transferência"); end
endmodule
