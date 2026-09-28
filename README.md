# Display de avião

Display VGA 640×480 com retículo, horizonte deslocável e inclinado, escada de
pitch, escalas de velocidade/altitude, heading em graus com N/E/S/W e alvo fixo.
A imagem é gerada por coordenadas, sem framebuffer, a 25 MHz (aproximadamente
59,52 Hz). Pitch, roll e heading são simulados por controles da placa;
velocidade e altitude permanecem em 280 KT e 36000 FT.

## Modos NORMAL / DECLUTTER (RF-08)

O **SW0** seleciona o modo: desligado = NORMAL; ligado = DECLUTTER.
A entrada passa por sincronização e filtro de 10 ms; a seleção é aplicada no
início do blanking vertical. A inicialização é NORMAL, seguida da leitura de SW0.

- **NORMAL:** todos os símbolos e o indicador de identificação do sensor.
- **DECLUTTER:** retículo, horizonte com referências de pitch/roll e marcador
  de alvo. Escalas laterais, seus números, heading e indicador do sensor ficam ocultos.

Esta é a definição de itens críticos adotada para a demonstração acadêmica.
SW1..SW11 e BTNL/BTNC/BTNR ficam livres. O retículo é verde fixo;
os controles de cor foram removidos. Pitch, roll e heading funcionam nos dois modos.

## Módulos

- `rtl/top_reticula.sv`: integra os módulos e compõe RGB.
- `rtl/vga_controller.sv`: divisor de clock, coordenadas e sincronismos.
- `rtl/reticula_vga.sv`: máscara do retículo com espessura e vão configuráveis.
- `rtl/controle_modo.sv`: sincronização, debounce e seleção de modo entre quadros.
- `rtl/controle_heading.sv`: rumo em passos de 10 graus pelos botões BTNU/BTND.
- `rtl/simbologia_vga.sv`: horizonte deslocável, escalas de velocidade/altitude, heading variável e alvo fixo.
- `rtl/entrada_hud.sv`: transfere amostras de 100 para 25 MHz com confirmação.
- `rtl/dados_hud.sv`: recebe dados processados e aplica o conjunto entre quadros.
- `rtl/numeros_hud.sv`: desenha números e unidades com fonte 3x5 ampliada.
- `rtl/mma8452_i2c.sv`: lê WHO_AM_I; não fornece atitude da aeronave.
- `constraints/nexys_a7_reticula.xdc`: clock, VGA, JA e controles da Nexys A7.

## Horizonte simulado

SW12 ligado sozinho posiciona o horizonte 40 pixels acima (y=200).
SW13 ligado sozinho posiciona 40 pixels abaixo (y=280).
Ambos desligados ou ambos ligados mantêm y=240. O retículo permanece fixo.
As entradas passam por dois estágios de sincronização e a posição é aplicada
no blanking vertical. São três posições fixas, sem movimento contínuo nem
leitura de atitude do sensor. O retículo mantém a cor verde fixa.

SW14 sozinho inclina para a esquerda; SW15 sozinho, para a direita.
Ambos ligados ou desligados mantêm roll zero. A escada traz referências
±10/20/30/40 que acompanham pitch e roll; são referências de simulação,
sem calibração com sensores. BTNU aumenta heading em 10° e BTND reduz em 10°,
com retorno circular entre 0° e 350°.

## Escalas laterais

A escala de velocidade fica à esquerda (x=80), espelhada em relação à altitude
à direita (x=560). As duas têm oito marcas, espaçadas a cada 40 pixels, entre
y=100 e y=380. As marcas apontam para o centro da tela. São verdes e têm rótulos numéricos, com
passos de 20 KT e 200 FT. Os valores atuais iniciais são 280 KT e 36000 FT,
mostrados abaixo das barras. Esses valores são simulados.

A interface aceita velocidade, altitude, deslocamento de pitch e inclinação de
roll processados. Consulte [formatos e ligação futura do sensor](docs/entradas_hud.md).
A transferência entre clocks já está implementada. A calibração e a conversão
dos eixos brutos para atitude ainda dependem da montagem do sensor.

## Testar e gerar no Vivado

Na raiz do repositório, com Icarus Verilog instalado:

```sh
scripts/test.sh
```

Os testes verificam geometria, controles e um quadro VGA completo. A imagem de
simulação fica em `build/hud.ppm`.

Com Vivado no PATH, para **Nexys A7-100T / xc7a100tcsg324-1**:

```sh
vivado -mode batch -source scripts/build_vivado.tcl
```

O projeto fica em `build/vivado/reticula.xpr`; o bitstream fica em
`build/vivado/reticula.runs/impl_1/top_reticula.bit`. Também são gerados
`build/timing_summary.rpt`, `build/utilization.rpt`, `build/drc.rpt` e
`build/fmax.rpt` (estimativa por domínio, sem varredura de frequência).
Para projeto manual, adicione todos os `rtl/*.sv`, o XDC e defina `top_reticula`
como módulo principal. Remova apenas fontes antigas duplicadas, não os módulos `.sv` atuais.

Confira o modelo físico antes de programar. O script não atende à A7-50T sem
ajustar o dispositivo. O mapeamento foi conferido no
[Master XDC da Digilent](https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc).
Os controles utilizados nesta versão usam LVCMOS33.
O I²C já usa SDA em JA1/C17 e SCL em JA7/D17. A ligação, alimentação e pull-ups
do sensor externo precisam ser conferidos na montagem.

Com a placa correta ligada por USB:

```sh
vivado -mode batch -source scripts/program_board.tcl
```

A programação é volátil. Verifique estabilidade da imagem, vão central, modos de exibição e ausência de cor fora da área ativa. A nova versão não foi gravada
na placa durante esta revisão.

Os números antigos de utilização e timing não representam esta versão.
Consulte [arquitetura e validação de RF-08](docs/rf08.md) para os resultados
atuais e [a auditoria anterior](docs/auditoria.md) como registro histórico.

## Integração futura

Quando o hardware estiver disponível, integrar o conversor de nível lógico
para a interface de 5 V, um switch externo e um módulo de giroscópio/acelerômetro.
A escolha dos modelos, alimentação, níveis, pinagem e protocolo será feita com
os componentes em mãos. A referência a 5 V é da interface a adaptar, não uma
instrução para aplicar 5 V diretamente aos pinos da FPGA.

O código de identificação I²C existente foi preservado como extensão. Ele não
comprova leitura de atitude nem integração do futuro módulo. Não é necessário
ampliar essa parte para concluir RF-08. Target lock fica como design goal;
GPS, longitude, localização, framebuffer e novos efeitos ficam fora desta etapa.

## Especificação do trabalho

Obejetivo:
	-Tela VGA com reticulo central
	-Horizonte artificial com deslocamento configuravel
	-Escala de altitude
	-idicador de velocidade/diração e marcador de alvo 
	-todos simultaneos

Controlado por hardware: switches e botões da Nexys A7 variam parâmetros de voo simulados em
tempo real.	


On-the-fly & pure logic: toda simbologia é gerada proceduralmente, pixel a pixel, por lógica
combinacional e sequencial em FPGA.

Dentro do escopo 								Fora do escopo
_____________________________________________________________________________________________________________________
VGA 640x480 ou resolução reduzida compatível com o	|	HDMI, DisplayPort ou frame buffer (memória) externo. |
laboratório. 				
________________________________________________________|____________________________________________________________
Retículo, horizonte, escalas, marcador de alvo e	|	 Renderização 3D, OpenGL ou fontes complexas.	     |
indicadores simples.		
________________________________________________________|____________________________________________________________|		
Entradas por switches/botões para variar parâmetros.	|	Sensores reais					
________________________________________________________|____________________________________________________________|

Requisitos Funcionais — O Que o Sistema Deve Fazer
RF-01 Gerar sinais hsync, vsync e região ativa VGA
RF-02 Gerar coordenadas x/y para cada pixel ativo
RF-03 Renderizar retículo central
RF-04 Renderizar linha de horizonte com deslocamento configurável
RF-05 Renderizar escala vertical de altitude
RF-06 Renderizar escala horizontal ou indicador de direção
RF-07 Renderizar marcador de alvo
RF-08 Selecionar pelo menos dois modos de exibição
RF-09 Atualizar símbolos em tempo real sem travar o frame
RF-10 Manter todos os elementos dentro da área ativa
Requisitos Funcionais — Adicionais (Design Goals)
DG-01 Capacidade de “travar” o alvo
RF-02 Dois modos de exibição: modo normal (todos os símbolos) e modo declutter (somente itens críticos).

Simbologia - Exemplo
• Retículo Central: Referência fixa de apontamento utilizada para
alinhamento da aeronave e visualização da linha de visada do piloto.
• Linha de Horizonte (deslocamento): Representa a atitude longitudinal
da aeronave em relação ao horizonte.
• Escala Vertical de Altitude: Fornece indicação contínua da altitude da
aeronave.
• Escala Horizontal / Indicador de Direção: Apresenta a referência de
rumo ou proa da aeronave.
• Marcador de Alvo / Navegação: Indica a direção de um alvo ou ponto de
navegação, guiando o piloto até sua posição.
*a simbologia pode ser mais simples que o exemplo, desde que compreensível
Examples:
https://www.youtube.com/watch?v=pP7gadhCmWc
https://www.youtube.com/watch?v=W1G06-JCJFk

Sugestão de Como Chegar ao MVP + Req Não Funcionais
1)()
VGA Timing
Implementar e validar em simulação os sinais hsync/vsync com temporização
correta; verificar contadores de linha e coluna
2)()
Coordenadas e Primitivas
Criar gerador x/y; codificar comparadores simples para linha horizontal, linha
vertical, retângulo e marcador
3)()
Compositor e Modos
Integrar todos os symbol generators; definir lógica de prioridade; implementar
seleção de modo via switch
4)()
()Síntese e Demo FPGA
()Sintetizar e implementar no Vivado para Artix-7
()Verificar Fmax e utilização de recursos
()Demonstrar em monitor VGA
()Requisitos não funcionais
()Ponto de atenção técnico: a geração procedural
Sem memória de frame, exige que cada
Símbolo seja avaliado dentro do ciclo de pixel.
Latência combinacional é um risco a monitorar.

● Não usar framebuffer externo; geração procedural por coordenadas
● Modularizar em gerador VGA, gerador de símbolos e compositor
● Apresentar relatório de utilização e Fmax
● Permitir demonstração direta em monitor VGA

clk In Clock do sistema ou derivado para VGA (~25 MHz)
_________________________________________________________________________________________________
rst_n 		| In 	|	Reset
cfg_pitch_up 	| In 	|	Atitude vertical “para cima”, mapeado em switch
cfg_pitch_down 	| In 	|	Atitude vertical “para baixo”, mapeado em switch
cfg_roll_left 	| In 	|	Deslocamento / inclinação para esquerda, switch
cfg_roll_right 	| In 	|	Deslocamento / inclinação para direita, switch
target_lock 	| In 	|	Quando pressionado, fixa a posição do alvo relativo ao horizonte
display_mode 	| In 	|	Seleciona modo normal ou declutter
hsync / vsync 	| Out 	|	Sincronismo horizontal e vertical VGA
rgb 		| Out 	|	Sinal RGB conectado ao conector VGA da Nexys A7
