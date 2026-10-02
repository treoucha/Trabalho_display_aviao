# Display de avião

Display VGA 640×480 com retículo, horizonte deslocável e inclinado, escada de
pitch, escalas de velocidade/altitude, heading em graus com N/E/S/W e alvo fixo.
A imagem é gerada por coordenadas, sem framebuffer, a 25 MHz (aproximadamente
59,52 Hz). Pitch e roll vêm do MPU6050 após calibração de bancada. Heading continua
nos botões; velocidade e altitude permanecem simuladas em 280 KT e 36000 FT.

## O que aparece na tela

| Elemento | O que significa | Como funciona neste projeto |
| --- | --- | --- |
| Retículo | Cruz de referência no centro da tela, com um vão no meio. Serve como referência de apontamento. | Fica parado e verde, com traços de 1 pixel, mesmo quando o horizonte muda. O desenho está em `rtl/reticula_vga.sv`. |
| Horizonte artificial | Linha que representa a referência do horizonte. | Sobe, desce e inclina conforme a estimativa do MPU6050. É desenhado em `rtl/simbologia_vga.sv`. |
| Escada de pitch | Marcas que ajudam a visualizar a atitude de nariz para cima ou para baixo. | Acompanha o horizonte, com referências ±10/20/30/40 de simulação, sem correspondência angular calibrada dessas marcas. |
| Escala de velocidade | Indicação à esquerda, em nós (KT). | O valor fornecido pelo projeto é fixo em 280 KT. |
| Escala de altitude | Indicação à direita, em pés (FT). | O valor fornecido pelo projeto é fixo em 36000 FT. |
| Heading (rumo) | Direção em graus, acompanhada das letras N/E/S/W. | Varia pelos botões BTNU e BTND, em passos de 10°. |
| Marcador de alvo | Símbolo que representa um alvo na demonstração. | Tem posição fixa; ainda não rastreia nem trava um alvo. |
| Indicador do sensor | Mostra se a atitude está pronta. | Verde após calibração; vermelho durante calibração, falha de leitura ou orientação inválida. |

**Retículo e horizonte são elementos diferentes:** o retículo é a referência
fixa central; o horizonte se desloca e inclina em relação a essa referência.

## O que cada controle da placa faz

| Controle | O que altera |
| --- | --- |
| SW0 | Seleciona NORMAL (desligado) ou DECLUTTER (ligado). |
| BTNU | Aumenta o heading em 10°. |
| BTND | Diminui o heading em 10°. |
| SW1 a SW15 e BTNL/BTNC/BTNR | Sem função nesta versão. |

SW12 a SW15 permanecem no topo físico, mas não controlam mais o horizonte.
O retículo permanece fixo; os botões de heading não alteram pitch/roll.

## Modos NORMAL / DECLUTTER (RF-08)

O **SW0** seleciona o modo: desligado = NORMAL; ligado = DECLUTTER.
A entrada passa por sincronização e filtro de 10 ms; a seleção é aplicada no
início do blanking vertical. A inicialização é NORMAL, seguida da leitura de SW0.

- **NORMAL:** todos os símbolos e o indicador de estado do sensor.
- **DECLUTTER:** retículo, horizonte com referências de pitch/roll e marcador
  de alvo. Escalas laterais, seus números, heading e indicador do sensor ficam ocultos.

Esta é a definição de itens críticos adotada para a demonstração acadêmica.
SW1..SW15 e BTNL/BTNC/BTNR ficam livres. O retículo é verde fixo;
os controles de cor foram removidos. Pitch, roll e heading funcionam nos dois modos.

## Qual arquivo controla cada parte

### Desenho da tela

| Arquivo | Responsabilidade |
| --- | --- |
| `rtl/reticula_vga.sv` | Define o formato do retículo: espessura, tamanho e vão central. |
| `rtl/simbologia_vga.sv` | Desenha horizonte, escada de pitch, escalas laterais, direção e marcador de alvo. |
| `rtl/numeros_hud.sv` | Desenha números e unidades com uma fonte 3×5 ampliada. |
| `rtl/top_reticula.sv` | Liga os módulos, combina os símbolos, define as saídas de cor e quais elementos aparecem em cada modo. |

### Controles e dados

| Arquivo | Responsabilidade |
| --- | --- |
| `rtl/controle_modo.sv` | Recebe SW0, sincroniza e filtra a entrada, e aplica o modo entre quadros. |
| `rtl/controle_heading.sv` | Recebe BTNU/BTND e calcula o heading em passos de 10°. |
| `rtl/top_reticula.sv` | Integra sensor, estimativa de atitude, heading e valores fixos de velocidade/altitude. |
| `rtl/entrada_hud.sv` | Transfere o conjunto de dados do clock de 100 MHz para o de 25 MHz com confirmação. |
| `rtl/dados_hud.sv` | Recebe os dados processados e aplica o conjunto entre quadros. |
| `rtl/mpu6050_i2c.sv` | Identifica e configura o MPU6050 e publica os seis eixos juntos após cada leitura. |
| `rtl/atitude_mpu6050.sv` | Calibra o nível, filtra a gravidade e calcula o deslocamento e a inclinação do horizonte. |

### Sinal VGA e ligação com a placa

| Arquivo | Responsabilidade |
| --- | --- |
| `rtl/vga_controller.sv` | Gera o clock de pixel, as coordenadas da imagem e os sincronismos VGA. |
| `constraints/nexys_a7_reticula.xdc` | Associa os sinais do projeto aos pinos da Nexys A7 e define as restrições de clock. |
| `scripts/build_vivado.tcl` | Cria o projeto no Vivado, inclui os arquivos RTL e gera o bitstream. |
| `scripts/program_board.tcl` | Programa a FPGA com o bitstream gerado. |

## Horizonte pelo MPU6050

Ao ligar, deixe o sensor parado e aproximadamente nivelado, com Z positivo
(cerca de +1 g). O sistema usa 64 amostras estáveis para definir o zero.
Aguarde o indicador ficar verde no modo NORMAL; normalmente leva cerca de
1 a 2 segundos. Movimento durante a calibração reinicia a contagem.

Depois, incline devagar o módulo. X positivo em relação ao nível calibrado
move o horizonte para baixo; Y positivo faz a linha descer para a direita.
A montagem deve respeitar os eixos impressos no módulo. A escala é limitada
a ±80 pixels de pitch e ±128 de inclinação Q8. O retículo continua fixo.
As referências ±10/20/30/40 da escada são gráficas, sem calibração em graus.

A estimativa usa a direção da gravidade, com filtro exponencial. O giroscópio
verifica movimento durante a calibração; não há fusão ou integração giroscópica.
Esta versão serve para demonstração com movimentos lentos, próxima do nível.
Aceleração linear, vibração e movimentos rápidos podem distorcer a estimativa.

Na desconexão, falta de amostras por 50 ms ou Z menor que 0,5 g, o horizonte
mantém a última posição e o indicador fica vermelho no próximo quadro.
Após reconectar, deixe o módulo parado novamente para recalibrar. Para mudar
o zero manualmente, reprograme a FPGA ou desconecte e reconecte o sensor.
No modo DECLUTTER o indicador permanece oculto, como os demais itens não críticos.

Ligação: SDA em JA1/C17, SCL em JA7/D17 e GND comum. O endereço configurado
é 0x68 (AD0 baixo). Confira alimentação e pull-ups do módulo; SDA/SCL devem
usar níveis compatíveis com 3,3 V. Não aplique 5 V nos sinais da FPGA.
Consulte [o fluxo de dados, a calibração e os testes](docs/entradas_hud.md).

BTNU aumenta heading em 10° e BTND reduz em 10°, com retorno circular
entre 0° e 350°. Esse rumo não é calculado pelo MPU6050.

## Escalas laterais

A escala de velocidade fica à esquerda (x=80), espelhada em relação à altitude
à direita (x=560). As duas têm oito marcas, espaçadas a cada 40 pixels, entre
y=100 e y=380. As marcas apontam para o centro da tela. São verdes e têm rótulos numéricos, com
passos de 20 KT e 200 FT. Os valores atuais iniciais são 280 KT e 36000 FT,
mostrados abaixo das barras. Esses valores são simulados.

A interface aceita velocidade, altitude, deslocamento de pitch e inclinação de
roll processados. Consulte [os formatos e a integração do sensor](docs/entradas_hud.md).
A transferência entre clocks preserva amostras completas; a aplicação no
desenho ocorre entre quadros.

## GitHub, Vivado e placa: etapas separadas

| Etapa | O que faz |
| --- | --- |
| GitHub | Armazena os arquivos e o histórico de versões do projeto. |
| `git pull origin main` | Traz as atualizações para a pasta local do repositório. |
| Vivado | Usa os arquivos adicionados ao projeto para executar síntese, implementação e gerar o `.bit`. |
| Program Device | Carrega o `.bit` escolhido na FPGA. Só então a placa passa a executar esse circuito. |

Atualizar pelo Git não adiciona automaticamente um módulo novo a um projeto
Vivado já aberto e não reprograma a placa.

Se a síntese mostrar `module 'controle_modo' not found` após a atualização:

1. Confirme que `rtl/controle_modo.sv` existe na pasta atualizada.
2. No Vivado, use **Add Sources → Add or create design sources → Add Files**
   e inclua esse arquivo em **Design Sources**.
3. Confira se os demais arquivos `rtl/*.sv` atuais estão incluídos e se
   `top_reticula` é o módulo principal.
4. Execute novamente **Run Synthesis** e **Generate Bitstream**.
5. Em **Program Device**, selecione o `.bit` recém-gerado.

O script de geração abaixo inclui todos os `rtl/*.sv` ao criar o projeto.

## Testar e gerar no Vivado

Na raiz do repositório, com Icarus Verilog instalado:

```sh
scripts/test.sh
```

Os testes verificam I²C, calibração, sinais dos eixos, desconexão, geometria,
controles e quadros VGA completos. A imagem de
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

Os [resultados da integração MPU6050](docs/entradas_hud.md#resultados-de-validação)
incluem testes e implementação no Vivado. Os números antigos de utilização e
timing não representam esta versão. Consulte [arquitetura e validação de RF-08](docs/rf08.md) como registro da versão anterior e [a auditoria anterior](docs/auditoria.md) como registro histórico.

## Extensões futuras

Fusão com o giroscópio, fontes reais de velocidade/altitude e target lock
permanecem fora desta demonstração. O leitor antigo `mma8452_i2c.sv` foi
preservado, mas não está instanciado. Há somente um mestre no barramento I²C.

## Especificação do trabalho

Texto original da proposta, preservado como referência. A integração do
MPU6050 descrita acima é uma extensão ao escopo original.

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
