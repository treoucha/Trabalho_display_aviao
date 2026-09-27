# Auditoria do display e validação do retículo

Data: 27/09/2026. Base remota: `46d07015dda619fe59415b2e3bdf9d00ca3fd6c7`.
A cópia local estava limpa em `6207870` e foi atualizada por fast-forward.

## Estado encontrado

O topo já instanciava controlador VGA, retículo, simbologia estática e leitor de
identificação I²C. O README ainda dizia que os símbolos não existiam.
`reticula_vga.sv` usava limites inclusivos nas duas bordas, gerando três pixels
para ESPESSURA=2. `vga_controller.sv` registrava HS/VS a partir dos contadores
anteriores, deixando-os um pixel atrasados. Não havia botões, switches ou testes.

O XDC já continha clock de entrada de 100 MHz, clock derivado de 25 MHz, VGA e
I²C em JA1/JA7. Não foi necessário inventar pinagem. Os 32 sinais físicos atuais
foram conferidos por pino e IOSTANDARD no Master XDC da Nexys A7-100T da Digilent.
Essa conferência não identifica a placa física nem confirma a ligação do sensor.

A foto enviada pelo grupo mostra retículo branco, horizonte/escala verdes, alvo
vermelho e indicador vermelho no canto. As faixas claras horizontais não estão
na lógica de desenho nem apareceram na simulação. A causa na montagem continua
pendente; a foto não permite atribuí-la ao timing, cabo, monitor ou câmera.

## Alterações

1. Limite superior exclusivo na espessura, preservando extensão e vão existentes.
2. HS/VS combinacionais a partir das mesmas coordenadas usadas pelo desenho.
3. `controle_cor.sv`: dois estágios de sincronização, debounce de 10 ms por botão,
   alternância independente de R/G/B e aplicação de cor no blanking vertical.
4. Três botões e 12 switches no topo e no XDC; verde como canal inicial.
5. Testes de regressão e documentação atualizada. Sensor e simbologia preservados.

## Validação executada

- Icarus Verilog: elaboração do topo e três testbenches aprovados.
- Retículo: varredura 800×525 para espessuras 1/2/3, contagens 136/272/408,
  bordas, vão zero, vão seis e bloqueio na região não visível.
- Controles: repique curto rejeitado, pressão longa sem repetição, soltura,
  segunda pressão, botões simultâneos, 16 níveis por canal e retenção da cor.
  O teste usa quatro ciclos de debounce para reduzir o tempo de simulação;
  o hardware usa 250.000 ciclos a 25 MHz.
- VGA integrado: 420.000 posições em um quadro, 307.200 ativas, HS baixo por
  96 pixels/linha, VS baixo por duas linhas, período de pixel de 40 ns,
  alinhamento e RGB preto no blanking. Imagem extraída do RTL em `build/hud.ppm`.
- Verilator 5.020: lint sem erro, com avisos de expansão de largura entre
  coordenadas e parâmetros inteiros, `sensor_id` não utilizado e falta de newline
  em dois módulos existentes. Não foi feita reformatação geral.
- Vivado 2026.1: síntese, posicionamento, roteamento e bitstream concluídos para
  xc7a100tcsg324-1. 217 LUTs (0,34%), 170 flip-flops (0,13%), zero latches.
  WNS +4,391 ns; TNS 0; WHS +0,122 ns. Nenhum endpoint interno sem constraint.

## Limitações e pendências

O DRC tem dois avisos: CFGBVS-1 (CFGBVS/CONFIG_VOLTAGE ausentes) e RPBF-3
(buffer de entrada incompleto em i2c_scl, declarado inout mas não lido).
Há entradas/saídas sem delays externos: o relatório lista 16 de cada categoria.
As entradas manuais têm exceção até o primeiro estágio de sincronização, mas a
interface VGA e o sensor ainda exigem análise elétrica apropriada. Não foram
inventados delays nem tensões para eliminar avisos. WNS positivo se refere aos
caminhos restringidos, não comprova temporização externa ou Fmax global.

O divisor de pixel existente foi mantido e reconhecido como clock gerado.
25 MHz resulta em 59,52 Hz, não exatamente 60 Hz; a aceitação deve ser confirmada
no monitor. Não há reset externo: registradores inicializados dependem da
configuração da FPGA Xilinx. Parâmetros do retículo pressupõem dimensões positivas
e geometria dentro da tela. Os switches não são um barramento de atualização
atômica e podem passar por valores intermediários durante movimentação manual.

O módulo I²C só verifica WHO_AM_I; não calcula pitch/roll, não trata clock stretching
e não foi validado com um modelo do sensor nesta revisão. Sua lógica foi preservada.
A ausência do sensor deixa o indicador vermelho; não bloqueia o HUD.
A nova versão não foi testada fisicamente. A foto recebida documenta a versão anterior.

## Commits sugeridos

1. `Corrige espessura do retículo e alinhamento VGA` (RTL e testes de geometria/timing).
2. `Adiciona controles RGB do retículo` (controle, topo, XDC e teste de cor).
3. `Documenta arquitetura e validação do display` (README, auditoria e relatório).

Para que cada commit rode isoladamente, inclua o teste integrado e o runner no
segundo commit, junto às novas portas do topo. Não foram feitos commits ou push.

## Fonte da pinagem

Digilent, Nexys-A7-100T-Master.xdc, consultado em 27/09/2026:
https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc
