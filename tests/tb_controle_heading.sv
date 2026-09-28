module tb_controle_heading;

    logic clk = 1'b0;
    logic [1:0] btn = 2'b00;
    wire [8:0] heading;

    always #5 clk = ~clk;

    controle_heading #(
        .DEBOUNCE_CYCLES(3)
    ) dut (
        .clk(clk),
        .btn(btn),
        .heading_deg(heading)
    );

    task automatic pressionar(input integer botao);
        begin
            btn[botao] = 1'b1;
            repeat (6) @(posedge clk);

            btn[botao] = 1'b0;
            repeat (6) @(posedge clk);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);

        if (heading !== 9'd0)
            $fatal(1, "Heading inicial incorreto: %0d", heading);

        pressionar(0);
        if (heading !== 9'd10)
            $fatal(1, "BTNU esperado 10, obtido %0d", heading);

        pressionar(0);
        if (heading !== 9'd20)
            $fatal(1, "BTNU esperado 20, obtido %0d", heading);

        pressionar(1);
        if (heading !== 9'd10)
            $fatal(1, "BTND esperado 10, obtido %0d", heading);

        pressionar(1);
        if (heading !== 9'd0)
            $fatal(1, "BTND esperado 0, obtido %0d", heading);

        pressionar(1);
        if (heading !== 9'd350)
            $fatal(1, "Wrap 0 para 350 falhou: %0d", heading);

        pressionar(0);
        if (heading !== 9'd0)
            $fatal(1, "Wrap 350 para 0 falhou: %0d", heading);

        btn = 2'b11;
        repeat (6) @(posedge clk);

        btn = 2'b00;
        repeat (6) @(posedge clk);

        if (heading !== 9'd0)
            $fatal(1, "Botoes simultaneos alteraram heading: %0d", heading);

        $display("PASS heading: incremento, decremento, wrap e botoes simultaneos");
        $finish;
    end

endmodule
