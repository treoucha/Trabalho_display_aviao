# Entradas do HUD

O MPU6050 e o estimador trabalham a 100 MHz. A ponte `entrada_hud` transfere
um conjunto completo para 25 MHz; `dados_hud` aplica o conjunto entre quadros.
Os barramentos abaixo são internos e não acrescentam pinos à placa.

| Entrada de dados_hud | Formato | Significado |
| --- | --- | --- |
| velocidade_kt_in | unsigned [9:0] | Nós inteiros, limitado a 0..999 |
| altitude_ft_in | unsigned [16:0] | Pés inteiros, limitado a 0..99999 |
| pitch_px_in | signed [10:0] | Deslocamento vertical do horizonte, limitado a -80..80 pixels |
| roll_q8_in | signed [9:0] | Inclinação em pixels por 256 pixels horizontais, limitada a -128..128 |
| heading_deg_in | unsigned [8:0] | Rumo pelos botões, limitado a 0..359 graus |
| dados_validos | 1 bit | Amostra completa disponível na borda de clk |
| clk | 25 MHz | Mesmo clock de pixel do display |

Um pitch positivo desloca o horizonte para baixo (convenção de nariz para cima).
Roll positivo faz a linha descer para a direita. `roll_q8=64` significa inclinação
1/4: em x=192 a linha sobe 32 pixels; em x=448 desce 32 pixels. Esse sinal não é
um ângulo em graus. O desenho usa inclinação linear, não rotação rígida de todos
os símbolos. As marcas acompanham a linha, e as escalas/números ficam verticais.

A última amostra válida fica em um buffer. O conjunto inteiro passa ao desenho
em x=0, y=480, preservando o quadro. Uma amostra que coincide com essa borda fica
para o quadro seguinte. Sem novas amostras, mantém-se o último conjunto; o estimador detecta
a ausência de leituras por 50 ms e invalida o indicador de estado.

## Leitura e configuração

`mpu6050_i2c.sv` é o único mestre instanciado. SDA usa JA1/C17 e SCL usa
JA7/D17, ambos open-drain. O módulo externo precisa de terra comum e pull-ups
compatíveis com 3,3 V. O endereço de sete bits é 0x68, com AD0 baixo.

O leitor espera 100 ms, lê WHO_AM_I (0x75, resposta 0x68), escreve zero em
PWR_MGMT_1 (0x6B) e espera mais 100 ms. Configura ACCEL_CONFIG (0x1C) e
GYRO_CONFIG (0x1B) em zero: ±2 g e ±250 graus/s. CONFIG (0x1A) recebe 3,
selecionando DLPF de 44 Hz para aceleração e 42 Hz para giroscópio.
A sequência segue o [mapa de registradores da InvenSense](https://www.invensense.com/wp-content/uploads/2015/02/MPU-6000-Register-Map1.pdf).

Cada leitura em rajada começa em 0x3B e coleta 14 bytes. A temperatura é
ignorada. Os seis eixos signed de 16 bits mudam juntos após STOP, acompanhados
de `amostra_valida` durante um ciclo de 100 MHz. Há uma espera de 10 ms entre
transações, além do tempo de transmissão. `sensor_ok` só sobe após a primeira
leitura completa. NACK ou timeout de 10 ms invalidam o estado e reiniciam a
identificação. SCL pode ser alongado pelo escravo dentro desse timeout.

## Calibração e orientação

`atitude_mpu6050.sv` aceita 64 leituras consecutivas próximas do nível:
|X| e |Y| menores que 4096, Z entre 14000 e 18000, e cada giroscópio com
módulo menor que 655. Na escala configurada, 1 g corresponde a 16384 e
1 grau/s a 131. A variação de cada acelerômetro entre amostras deve ser menor
que 256. Uma leitura que falha nesses critérios reinicia a calibração.

Monte Z para cima e deixe o módulo parado. A média das razões X/Z e Y/Z é o
zero da demonstração; não é uma calibração completa de bias e escala do sensor.
A convenção é explícita nos dados: X positivo relativo ao zero move o horizonte
para baixo, e Y positivo faz a linha descer para a direita. Confira a orientação
física pelos eixos do módulo antes de demonstrar.

Para cada amostra com Z >= 8192 (0,5 g), o módulo calcula `256*X/Z` e `256*Y/Z`
com divisão inteira sequencial de 24 ciclos por eixo, subtrai o zero e aplica
filtro exponencial de 1/4 por leitura, com quatro bits fracionários adicionais.
O pitch usa a razão X/Z multiplicada por 160 pixels; o roll usa Y/Z em Q8.
Os resultados são saturados em ±80 pixels e ±128 Q8, respectivamente.
Perto do nível, X/Z aproxima a tangente de pitch e Y/Z representa a inclinação
lateral. Não são ângulos Euler exatos para inclinações combinadas grandes.

A escada existente conserva suas marcas gráficas; seus números não indicam
ângulos medidos. O método pressupõe predominância da gravidade e movimentos
lentos. Não compensa aceleração linear. O giroscópio só impede calibração em
movimento; não existe fusão com giroscópio nesta versão.

## Amostras completas e falhas

O estimador publica pitch e roll na mesma borda. `u_entrada` recebe
`{velocidade_kt[9:0], altitude_ft[16:0], pitch_px[10:0], roll_q8[9:0], heading[8:0]}`,
um total de 57 bits. Seu `valido` fica em 1 para também transportar alterações
dos botões quando a atitude está retida. A ponte só captura quando `pronto`
está em 1 e mantém o barramento estável até a confirmação.

`dados_hud` publica a última amostra recebida no início do blanking vertical.
O indicador passa por dois estágios de sincronização e também só muda entre
quadros: verde exige leitura válida, calibração completa e orientação aceita.
No NORMAL, vermelho significa inicialização, calibração, orientação inválida
ou falha de leitura. No DECLUTTER o indicador continua oculto.

Z abaixo do limite retém a última atitude e invalida o indicador; ao voltar
à orientação aceita, a estimativa continua com o mesmo zero. NACK, timeout do
leitor ou 50 ms sem novas amostras descartam a calibração. Após a recuperação,
as próximas 64 leituras estáveis definem um novo zero. Os dados antigos ficam
retidos até isso ocorrer; durante a partida inicial o horizonte fica nivelado.

Velocidade e altitude permanecem em 280 KT e 36000 FT. Heading continua nos
botões. SW12..SW15 são reservados e não alteram mais a atitude.

## Números exibidos

Os valores atuais iniciais são 280 KT e 36000 FT, na parte inferior das escalas.
As oito marcas têm passo de 20 KT à esquerda e 200 FT à direita, com referência
no centro vertical y=240. Os rótulos de cima para baixo são 350..210 KT e
36700..35300 FT. O centro está entre duas marcas, como na geometria existente.
A fonte 3x5 é ampliada duas vezes, com supressão de zeros à esquerda. Rótulos
fora da faixa ficam vazios; os valores atuais são saturados por dados_hud.

## Verificar

Execute `bash scripts/test.sh`. O teste I²C usa um escravo simulado nos pinos
para verificar identificação, configuração, rajadas, ACK/NACK, alongamento de
clock, desconexão e recuperação. Os testes de atitude cobrem calibração,
movimento, sinais dos eixos, limites, Z inválido e ausência de amostras.
O teste sensor/HUD injeta eixos na saída do leitor e verifica a ponte e a
aplicação entre quadros; não substitui a verificação elétrica na placa.
 Os testes cobrem dez glifos, composição decimal,
espaçamento, limites numéricos, transferência entre clocks, buffer de amostras, mudança entre quadros,
pitch, roll positivo/negativo e preservação das escalas. O teste integrado gera
`build/hud.ppm`. Gere um novo bitstream e confira leitura dos números no monitor.

## Resultados de validação

Na revisão de 29/09/2026, passaram os testes de atitude com 64 amostras de
calibração, a integração sensor/HUD e os cenários I²C de identificação,
configuração, amostras completas, NACK, clock stretching, desconexão e SCL preso.
O teste I²C reduz a espera de partida para 1 ms; os tempos de bit permanecem
inalterados. Na FPGA, a espera de partida continua em 100 ms. O teste de
integração usa quatro amostras de calibração para encurtar a simulação.

A implementação no Vivado 2026.1, concluída em 28/09/2026 para
`xc7a100tcsg324-1`, gerou `build/vivado/reticula.runs/impl_1/top_reticula.bit`:

| Medida | Resultado |
| --- | --- |
| LUTs | 3109 |
| Flip-flops | 875 |
| Latches | 0 |
| DSPs | 1 |
| WNS / TNS | +0,861 ns / 0 ns |
| WHS / THS | +0,049 ns / 0 ns |

Os relatórios estão em `build/timing_summary.rpt`, `build/utilization.rpt` e
`build/drc.rpt`. Permanecem avisos de tensão de configuração (CFGBVS) e de
pipeline do DSP do desenho. Há entradas e saídas externas sem atrasos
especificados; o resultado de timing não valida eletricamente a montagem I²C.
O bitstream ainda não foi testado na placa física nesta revisão.
