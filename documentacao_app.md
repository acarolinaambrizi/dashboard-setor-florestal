# Documentação — Dashboard Indicadores do Setor Florestal (MG)

Este documento explica como o `app.R` funciona, por dentro, para quem for
manter ou continuar o desenvolvimento (você mesma daqui a uns meses, sua
orientadora, ou outra pessoa do LEMAF).

---

## 1. Visão geral

O app é um dashboard em Shiny com 4 abas:

| Aba | O que mostra |
|---|---|
| **Dados** | Tabela bruta filtrada por ano/trimestre, dicionário de variáveis, exportação para Excel |
| **Análises** | Gráficos de evolução, panorama de um período e mapa de calor ocupação × rendimento |
| **Sobre a PNAD Contínua** | Texto explicativo sobre a pesquisa |
| **Laboratório** | Página institucional do LEMAF (placeholder, a preencher) |

O app **não baixa dados da PNAD em tempo real** — isso seria lento demais.
Ele lê arquivos `.xlsx` já prontos, gerados pelo script de importação
(o que usa o pacote `PNADcIBGE`), de uma pasta local chamada `dados/`.

---

## 2. Fluxo de dados (o que acontece quando o app abre)

1. **Lê todos os `.xlsx`** da pasta `dados/` e empilha num único data frame
   (`dados_pnadc`). O ano e o trimestre de cada arquivo são extraídos do
   próprio nome do arquivo (ex.: `DADOSIC_202404.xlsx` → ano 2024,
   trimestre 4).
2. **Filtra pelo setor florestal**: mantém só as linhas em que
   `V4013 == "02000"` (código CNAE-Domiciliar de "Produção florestal",
   confirmado na documentação oficial do IBGE). Esse filtro roda **uma vez
   só**, na carga dos dados — o app inteiro já trabalha só com o setor
   florestal, não é uma opção que liga/desliga.
3. **Monta o dicionário** (`dicionario_pnad`): uma tabela com todas as
   variáveis usadas, organizadas em 4 grupos que espelham o script de
   importação original (`variaveis_gerais`, `variaveis_saude`,
   `variaveis_trabalho_primario`, mais o código de setor).

---

## 3. Aba "Dados"

- Filtros: **Ano** (um só) e **Trimestre** (várias caixas de marcação —
  pode combinar quantos quiser).
- Mostra a tabela filtrada e o dicionário de códigos, os dois com botão de
  exportação (Excel).
- Os IDs dos seletores aqui são `filtro_ano` e `filtro_trimestre` — **não
  têm nenhuma ligação** com os seletores da aba Análises (ver seção 4).

---

## 4. Aba "Análises"

Reproduz as análises do relatório da IC (as mesmas figuras: distribuição
por sexo, cor/raça, idade, escolaridade, carteira assinada, tipo de
vínculo, jornada de trabalho, tempo de serviço, ocupação × rendimento).

**Seletores próprios desta aba** (prefixo `an_`, independentes da aba
Dados):
- `an_variavel` — qual variável da PNAD está sendo analisada.
- `an_periodo` — intervalo de anos, usado só no gráfico de evolução.
- `an_ano` + `an_trimestre` — ano e trimestre(s) usados no panorama e no
  mapa de calor. `an_trimestre` aceita vários trimestres marcados ao mesmo
  tempo (ex.: só 1 e 2).
- `an_medida`, `an_dif40`, `an_tipo` — opções que só aparecem para certas
  variáveis (ver `conditionalPanel` no código).

**Os três gráficos:**

1. **`plot_evolucao`** — como a variável muda ao longo dos períodos
   (ano.trimestre) dentro do intervalo de anos escolhido. Comportamento
   diferente por tipo de variável:
   - `V20082` (idade): mostra média, mediana e moda.
   - `V4039` (horas trabalhadas): mostra a média, com opção de ver como
     diferença em relação a 40h.
   - Demais (categóricas): mostra % ou contagem de cada categoria.
2. **`plot_periodo`** — panorama de um período específico (o `an_ano` +
   `an_trimestre` escolhidos): histograma para idade, distribuição para
   horas trabalhadas, barras ou pizza para categóricas.
3. **`plot_heatmap`** — cruza ocupação (`V4010`) com faixa de rendimento
   (`V403311`) no período escolhido, sempre em mapa de calor.

**Função central: `preparar_var(df, var)`** — recebe a base e o código da
variável, devolve a mesma base com uma coluna `valor` já tratada (idade
calculada, horas convertidas para número, ocupação mapeada para nome, ou
simplesmente o texto da categoria). Os três gráficos partem dessa mesma
função, o que evita repetir a lógica de tratamento em cada um.

**Download dos gráficos**: cada gráfico primeiro é guardado como
`reactive` (`plot_evolucao`, `plot_periodo`, `plot_heatmap`) e depois é
tanto exibido na tela (`renderPlot`) quanto oferecido para download em PNG
via `baixar_grafico()` — assim o código do gráfico não se repete.

---

## 5. Como adicionar uma variável nova

1. Adicione o código e a descrição num dos vetores no topo do arquivo:
   `desc_gerais`, `desc_saude` ou `desc_trabalho` (o grupo deve
   corresponder a onde ela está no script de importação).
2. Se for uma variável **numérica** (tipo horas ou valores), adicione o
   código em `vars_numericas`.
3. Se ela tiver uma ordem natural de categorias (tipo faixas de
   rendimento), adicione essa ordem em `ordem_categorias`.
4. Se quiser rótulos mais amigáveis para as respostas (tipo "Sim"/"Não"),
   adicione em `rotulos_categorias`.
5. Pronto — ela já aparece sozinha no seletor "Variável" da aba Análises
   e no dicionário da aba Dados.

Para **esconder** uma variável do seletor de Análises sem tirá-la do
dicionário (caso da `V40132A`, cujo significado exato ainda não foi
confirmado), adicione o código em `vars_fora_da_analise`.

---

## 6. Limitações conhecidas

- **Sem peso amostral**: todos os cálculos (contagens, médias, %) são
  feitos sobre os registros da amostra, sem aplicar o peso amostral da
  PNAD Contínua (que se perde ao exportar só `$variables` do
  `get_pnadc()`). Os números são proporcionais, mas não são estimativas
  da população real. Isso está avisado na tela, mas vale considerar
  aplicar o peso numa versão futura.
- **`V40132A`**: o significado exato dessa variável não foi confirmado no
  dicionário oficial do IBGE — está fora do seletor de Análises até essa
  confirmação.
- **Sem filtro de região dentro de MG**: os microdados públicos da PNAD
  Contínua não trazem mesorregiões (Triângulo Mineiro, Zona da Mata etc.);
  a única quebra geográfica oficial é a variável `RM_RIDE`, que identifica
  apenas a Região Metropolitana de Belo Horizonte. Não implementado ainda.
- **Aba "Laboratório"**: só tem texto placeholder — falta preencher com
  informações reais (missão, equipe, contato) quando estiverem definidas.
- **Cards de indicadores**: os cards "Ocupados no setor", "Rendimento
  médio" e "Horas trabalhadas" que existiam numa versão anterior do app
  foram removidos; a decisão de trazê-los de volta (e onde) ainda está em
  aberto.

---

## 7. Como rodar o app

1. Coloque os arquivos `.xlsx` gerados pelo script de importação dentro
   de uma pasta chamada `dados/`, na mesma pasta do `app.R`.
2. Abra o `app.R` no RStudio.
3. `Session > Set Working Directory > To Source File Location`.
4. Clique em "Run App".

Pacotes necessários: `shiny`, `dplyr`, `DT`, `ggplot2`, `writexl`,
`readxl`, `tibble`.
