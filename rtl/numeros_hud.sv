// Fonte 3x5 ampliada 2x: escalas e valores atuais, sempre em verde no compositor.
module numeros_hud (
    input logic [9:0] pixel_x, pixel_y,
    input logic video_on,
    input logic [9:0] velocidade_kt,
    input logic [16:0] altitude_ft,
    output logic numeros_on
);
    function automatic logic [14:0] glifo(input integer codigo);
        case(codigo)
            0: glifo=15'b111_101_101_101_111;
            1: glifo=15'b010_110_010_010_111;
            2: glifo=15'b111_001_111_100_111;
            3: glifo=15'b111_001_111_001_111;
            4: glifo=15'b101_101_111_001_001;
            5: glifo=15'b111_100_111_001_111;
            6: glifo=15'b111_100_111_101_111;
            7: glifo=15'b111_001_010_010_010;
            8: glifo=15'b111_101_111_101_111;
            9: glifo=15'b111_101_111_001_111;
            10: glifo=15'b101_101_110_101_101; // K
            11: glifo=15'b111_010_010_010_010; // T
            12: glifo=15'b111_100_110_100_100; // F
            default: glifo='0;
        endcase
    endfunction
    // Conversão binário -> decimal por deslocamento, sem divisor em hardware.
    function automatic logic [19:0] decimal(input logic [16:0] binario);
        logic [19:0] bcd;
        bcd='0;
        for(integer bit_atual=16;bit_atual>=0;bit_atual=bit_atual-1) begin
            for(integer d=0;d<5;d=d+1)
                if(bcd[d*4 +: 4]>=5) bcd[d*4 +: 4]=bcd[d*4 +: 4]+4'd3;
            bcd={bcd[18:0],binario[bit_atual]};
        end
        return bcd;
    endfunction
    integer coluna,linha,valor,digitos,caractere,divisor,codigo;
    logic campo,unidade,direita;
    logic [14:0] bitmap;
    logic [19:0] bcd;
    always_comb begin
        coluna=0; linha=0; valor=0; digitos=0;
        caractere=0; divisor=1; codigo=15;
        campo=0; unidade=0; direita=0; bitmap='0; bcd='0;
        numeros_on=0;
        // Faixas externas: não sobrepõem barras ou o horizonte.
        if (pixel_x>=46 && pixel_x<70) begin
            coluna=int'(pixel_x)-46; digitos=3;
        end else if (pixel_x>=572 && pixel_x<612) begin
            coluna=int'(pixel_x)-572; digitos=5; direita=1;
        end
        if(digitos!=0) begin
            for(integer marca=0;marca<8;marca=marca+1) begin
                if(int'(pixel_y)>=95+40*marca && int'(pixel_y)<105+40*marca) begin
                    campo=1; linha=(int'(pixel_y)-95-40*marca)/2;
                    // Centro em y=240; as marcas ficam a +/-20,60,100,140 pixels.
                    valor=direita ? int'(altitude_ft)+700-200*marca : int'(velocidade_kt)+70-20*marca;
                end
            end
            if(pixel_y>=402 && pixel_y<412) begin
                campo=1; linha=(int'(pixel_y)-402)/2;
                valor=direita ? int'(altitude_ft) : int'(velocidade_kt);
            end
            if(pixel_y>=418 && pixel_y<428 && coluna<16) begin
                campo=1; unidade=1; linha=(int'(pixel_y)-418)/2;
            end
            caractere=coluna/8;
            if(unidade) codigo=(caractere==1) ? 11 : (direita ? 12 : 10);
            else begin
                // Marca fora da faixa numérica fica vazia; nunca dá volta para zero.
                if(valor<0 || valor>(direita ? 99999 : 999)) campo=0;
                bcd=decimal(17'(valor));
                case(digitos-1-caractere)
                    4: begin divisor=10000; codigo=int'(bcd[19:16]); end
                    3: begin divisor=1000; codigo=int'(bcd[15:12]); end
                    2: begin divisor=100; codigo=int'(bcd[11:8]); end
                    1: begin divisor=10; codigo=int'(bcd[7:4]); end
                    default: begin divisor=1; codigo=int'(bcd[3:0]); end
                endcase
                if(caractere<digitos-1 && valor<divisor) codigo=15;
            end
            bitmap=glifo(codigo);
            if(video_on && campo && (coluna%8)<6)
                numeros_on=bitmap[14-(linha*3+(coluna%8)/2)];
        end
    end
endmodule
