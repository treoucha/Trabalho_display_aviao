# Display de avião

O circuito atual desenha uma retícula branca com vão central sobre fundo preto,
em uma saída VGA de 640×480. Os controles e demais símbolos descritos na
especificação ainda não estão implementados.

## Estrutura do projeto

```text
.
├── README.md
├── constraints/
│   └── nexys_a7_reticula.xdc
└── rtl/
    ├── reticula_vga.sv
    ├── top_reticula.sv
    └── vga_controller.sv
```

- `rtl/`: módulos Verilog. O módulo principal é `top_reticula`.
- `constraints/`: restrições de pinos e clock da Nexys A7.

No Vivado, adicione os arquivos de `rtl/` como fontes de projeto e
`constraints/nexys_a7_reticula.xdc` como arquivo de restrições. Defina `top_reticula` como módulo principal.
Se estiver usando um projeto Vivado anterior, remova as referências a
`vga_controller.sv`, `vga_top.sv` e `nosso_xdc.xdc` antes de adicionar os novos arquivos.

O mapeamento JA está comentado no XDC como referência para a futura ligação do
acelerômetro; esta versão usa apenas o clock e a saída VGA.

## Gerar o projeto no Vivado

Para a Nexys A7-100T, execute na raiz do repositório, com o Vivado no PATH:

```sh
vivado -mode batch -source scripts/build_vivado.tcl
```

O projeto fica em `build/vivado/reticula.xpr`. O bitstream fica em
`build/vivado/reticula.runs/impl_1/top_reticula.bit`, e os relatórios de timing,
utilização e DRC ficam em `build/`.

Com a placa ligada e conectada por USB, programe a FPGA com:

```sh
vivado -mode batch -source scripts/program_board.tcl
```

A programação é volátil: ao desligar a placa, será necessário programá-la novamente.
No monitor VGA, confira a retícula branca centralizada, com vão central e fundo preto.

A implementação foi executada no Vivado 2026.1. O clock interno de pixel está
declarado em 25 MHz no XDC. Os relatórios ainda apontam ausência de delays de saída
VGA e das propriedades de tensão de configuração; a análise interna de timing não
substitui a validação da imagem no monitor.

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
