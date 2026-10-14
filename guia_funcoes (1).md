# Guia das principais funções — Dashboard Setor Florestal

Este documento explica as funções mais importantes que aparecem no
`app.R`, agrupadas por "família": as do Shiny (fazem a interface reagir),
as do `dplyr` (tratam os dados) e as do `ggplot2` (fazem os gráficos). No
final, tem uma seção só com as funções que **eu escrevi** especialmente
para este app — essas são as mais importantes de entender, porque não
existem em nenhum pacote, são exclusivas daqui.

A ideia não é decorar tudo de uma vez, mas ter onde consultar quando
esquecer o que uma função faz.

---

## 1. Funções do Shiny (o que faz a tela reagir)

### `reactive({ ... })`
Cria um "valor que se recalcula sozinho" toda vez que algo do qual ele
depende muda (um filtro, por exemplo). É como uma célula de planilha com
fórmula: você não roda ela manualmente, ela atualiza sozinha.

```r
dados_filtrados <- reactive({
  dados_pnadc %>% filter(ano == input$filtro_ano)
})
```

Para *usar* o resultado, sempre com parênteses: `dados_filtrados()`, não
`dados_filtrados`.

### `input$nome_do_campo`
É assim que o servidor lê o que o usuário escolheu na tela. Cada
`selectInput("filtro_ano", ...)` na UI vira `input$filtro_ano` no server.

### `output$nome <- render...({ ... })`
É o caminho contrário: manda algo do servidor **para** a tela. O `nome`
tem que bater com o `id` usado na UI (`plotOutput("grafico_evolucao")` ↔
`output$grafico_evolucao`).
- `renderPlot({...})` → gráfico
- `renderDT({...})` → tabela interativa (pacote DT)

### `req(x)`
"Exige" que `x` já tenha um valor antes de continuar. Se `x` ainda
estiver vazio (ex.: o usuário desmarcou todas as caixas de trimestre), o
Shiny simplesmente **para ali**, sem mostrar erro feio na tela.

```r
req(input$filtro_trimestre)  # só continua se tiver algo marcado
```

### `validate(need(condição, "mensagem"))`
Parecido com `req()`, mas mostra uma **mensagem escolhida por você** na
tela, em vez de só ficar em branco. Uso principal no app: avisar "Sem
dados para os filtros selecionados." em vez de um gráfico vazio ou um
erro confuso.

```r
validate(need(nrow(df) > 0, "Sem dados para o intervalo selecionado."))
```

### `downloadHandler(filename = ..., content = ...)`
Cria a lógica por trás de um `downloadButton`. `filename` é uma função
que devolve o nome do arquivo; `content` é uma função que recebe um
caminho temporário (`file`) e escreve o arquivo ali.

```r
downloadHandler(
  filename = function() "dados.xlsx",
  content  = function(file) write_xlsx(dados_filtrados(), file)
)
```

### `conditionalPanel(condition = "...", ...)`
Mostra ou esconde um controle da tela dependendo de uma condição escrita
em **JavaScript** (não em R!). No app, é usado para só mostrar o
seletor "Medida" quando a variável escolhida é categórica:

```r
conditionalPanel(
  condition = "input.an_variavel != 'V4039'",  # JS, não R
  radioButtons("an_medida", ...)
)
```

### Funções de entrada (inputs) usadas na UI
| Função | O que cria |
|---|---|
| `selectInput()` | Uma lista suspensa (escolher 1 opção) |
| `checkboxGroupInput()` | Várias caixinhas de marcar (escolher vários) |
| `sliderInput()` | Um controle deslizante (intervalo de anos) |
| `radioButtons()` | Botões de opção única lado a lado |
| `checkboxInput()` | Uma única caixinha (sim/não) |

---

## 2. Funções do `dplyr` (tratam os dados)

### O operador `%>%` ("pipe")
Lê-se "e depois". Pega o resultado de uma linha e passa para a próxima,
sem precisar guardar em variáveis intermediárias.

```r
dados_pnadc %>% filter(ano == 2024) %>% count(trimestre)
# é o mesmo que:
# count(filter(dados_pnadc, ano == 2024), trimestre)
# mas muito mais fácil de ler de cima para baixo
```

### `filter(condição)`
Mantém só as linhas que atendem à condição. É o "WHERE" do R.

```r
dados_pnadc %>% filter(V4013 == "02000")   # só linhas do setor florestal
```

### `mutate(nova_coluna = ...)`
Cria (ou substitui) uma coluna.

```r
df %>% mutate(idade = ano - V20082)
```

### `group_by(coluna) %>% summarise(...)`
Agrupa as linhas por uma coluna e calcula um resumo por grupo (média,
soma, contagem...). É o "GROUP BY" do R.

```r
df %>% group_by(ano) %>% summarise(media_horas = mean(V4039))
```

### `count(coluna)`
Atalho para contar quantas linhas existem de cada valor. Equivale a
`group_by(coluna) %>% summarise(n = n())`.

```r
df %>% count(trimestre)
```

### `recode(coluna, "valor_antigo" = "valor_novo")`
Troca valores por outros, mantendo o resto igual. Usado para deixar
"Sim"/"Não" mais claros ("Com carteira assinada" em vez de só "Sim").

### `arrange()` / `slice_head(n = ...)`
`arrange()` ordena as linhas; `slice_head(n = 8)` pega só as N primeiras
depois de ordenado. Usado em `agrupar_top()` para pegar as 8 categorias
mais frequentes.

---

## 3. Funções do `ggplot2` (fazem os gráficos)

Todo gráfico no app segue a mesma receita:

```r
ggplot(dados, aes(x = coluna_x, y = coluna_y, color = coluna_cor)) +
  geom_line() +          # o TIPO de gráfico (linha, barra, ponto...)
  labs(title = "...") +  # títulos e legendas
  theme_minimal()         # aparência visual
```

- **`ggplot(dados, aes(...))`** — declara os dados e quais colunas vão em
  qual eixo/cor. Não desenha nada sozinho, só prepara.
- **`geom_line()` / `geom_col()` / `geom_point()` / `geom_histogram()` /
  `geom_tile()`** — cada um desenha um tipo de gráfico (linha, barra,
  pontos, histograma, mapa de calor). É só trocar o `geom_` para mudar o
  tipo de visualização, mantendo os mesmos dados.
- **`labs(title = , x = , y = )`** — títulos e nomes dos eixos.
- **`scale_color_viridis_d()` / `scale_fill_viridis_c()`** — paletas de
  cor (a "d" é para categorias, a "c" é para números contínuos).
- **`theme_minimal()`** — um visual limpo, sem fundo cinza. Trocar por
  outro `theme_...()` muda a aparência inteira do gráfico de uma vez.
- **`coord_flip()`** — vira o gráfico de lado (barras verticais viram
  horizontais). Usado no panorama para caber nomes de categoria longos.

---

## 4. Funções que eu criei para este app

Estas não existem em nenhum pacote — são específicas do `app.R`. Ficam
todas no topo do arquivo, antes do `ui <- fluidPage(...)`.

### `preparar_var(df, var)`
**A função mais importante do app.** Recebe a base de dados e o código
de uma variável (ex.: `"V2007"`), e devolve a mesma base com uma coluna
nova chamada `valor`, já tratada:
- Se for `V20082` (ano de nascimento) → calcula a idade.
- Se for numérica (`V4039`) → converte para número.
- Se for `V4010` (ocupação) → troca o código pelo nome da profissão.
- Qualquer outra → mantém como categoria (texto).

Os três gráficos da aba Análises partem dela — é por isso que basta
trocar a variável no seletor que os três gráficos mudam juntos.

### `rotulo_variavel(var)`
Devolve o nome bonito de uma variável para usar em título de gráfico
(`"V2007"` → `"Sexo"`). Só olha no dicionário e devolve o texto.

### `agrupar_top(df, max_cat = 8)`
Quando uma variável tem muitas categorias diferentes (ex.: profissões),
mantém só as 8 mais frequentes e junta o resto em uma categoria
"Outras" — evita gráfico poluído com 30 fatias minúsculas.

### `ordenar_categorias(df, var)`
Algumas variáveis têm uma ordem que **não é alfabética** mas faz mais
sentido (faixas de rendimento do menor para o maior, por exemplo). Essa
função aplica essa ordem quando ela existe (guardada em
`ordem_categorias`), ou ordena alfabeticamente quando não existe.

### `filtrar_periodo(df, ano_sel, tri_sel)`
Filtra a base por um ano e um ou mais trimestres de uma vez. Existe para
não repetir essa mesma lógica de filtro em três lugares diferentes do
código (panorama, mapa de calor).

### `texto_periodo(ano_sel, tri_sel)`
Monta o texto que aparece nos títulos dos gráficos: `"2025.2"` se for um
trimestre só, ou `"2025 (trimestres 1, 2)"` se for mais de um.

### `moda(x)`
R não tem uma função pronta para calcular a moda (valor mais frequente)
de um jeito simples — só existem `mean()` e `median()` prontas. Essa
função preenche esse buraco, usada para a idade.

### `mapear_ocupacao(x)`
Troca os códigos CBO da variável `V4010` pelos nomes reais das
profissões (ex.: `"3143"` → `"Técnicos florestais"`), usando a lista
`ocupacao_map`. Qualquer código fora dessa lista vira `"Outras
ocupações"`.

### `baixar_grafico(nome_fn, plot_reativo, largura, altura)`
Gera o `downloadHandler` de um gráfico em PNG. Em vez de escrever esse
bloco três vezes (um para cada gráfico), essa função recebe o gráfico
pronto e devolve o botão de download já configurado. É um exemplo de
"função que cria outra função" — recebe `plot_reativo` (o `reactive` do
gráfico) e usa `ggsave()` por trás para salvar como imagem.

---

## Glossário rápido

| Termo | O que significa |
|---|---|
| **Reativo / reactive** | Um valor que se atualiza sozinho quando algo do qual depende muda |
| **`input$x` / `output$x`** | Ponte entre a tela (UI) e a lógica (server) |
| **Pipe `%>%`** | "e depois" — encadeia operações sem variáveis intermediárias |
| **Data frame / tibble** | A "tabela" onde os dados ficam guardados em R |
| **`NA`** | Valor ausente/faltando (equivalente a célula vazia numa planilha) |

---

*Dica de estudo: sempre que uma função te confundir no código, procure o
nome dela aqui primeiro. Se não estiver, é porque vem de um pacote — pode
digitar `?nome_da_funcao` no console do R para abrir a ajuda oficial.*
