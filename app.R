# ============================================================
# DASHBOARD - INDICADORES DO SETOR FLORESTAL (PNAD CONTÍNUA)
# Ver documentacao_app.md para detalhes sobre cada parte.
# ============================================================

library(shiny)
library(dplyr)
library(DT)
library(ggplot2)
library(writexl)
library(readxl)
library(tibble)
library(leaflet)
library(sf)
library(shinyWidgets)  # pickerInput: dropdown com seta igual ao "Ano", permitindo marcar vários

# ---- 1) Carregamento dos dados ------------------------------
pasta_dados <- "dados/"
arquivos <- list.files(pasta_dados, pattern = "\\.xlsx$", full.names = TRUE)
cache_dados <- file.path(pasta_dados, "_cache_dados_pnadc.rds")

# Mude para TRUE sempre que adicionar/trocar um .xlsx na pasta "dados/" e
# quiser forçar a reimportação (senão, enquanto o cache existir e for mais
# recente que os arquivos, ele é reaproveitado e a abertura do app fica
# muito mais rápida).
forcar_reimportacao <- FALSE

cache_valido <- file.exists(cache_dados) &&
  !forcar_reimportacao &&
  all(file.info(cache_dados)$mtime > file.info(arquivos)$mtime)

if (cache_valido) {

  dados_pnadc <- readRDS(cache_dados)

} else {

  # col_types = "text" evita que o readxl "adivinhe" o tipo de cada coluna
  # pelas primeiras linhas (o que estava descartando respostas da V4006A
  # como NA e gerando milhares de avisos no console, deixando a leitura
  # muito mais lenta). As conversões numéricas necessárias (V4039, V20082,
  # etc.) já são feitas depois, em preparar_var().
  dados_pnadc <- lapply(arquivos, function(arq) {
    df <- read_xlsx(arq, col_types = "text")
    codigo <- gsub("[^0-9]", "", basename(arq))
    df$ano       <- as.numeric(substr(codigo, 1, 4))
    df$trimestre <- as.numeric(substr(codigo, 5, 6))
    df
  }) %>% bind_rows()

  # Filtro pelo setor florestal (CNAE-Domiciliar "02000") — feito antes de
  # salvar o cache, para o arquivo .rds ficar pequeno e rápido de carregar.
  dados_pnadc <- dados_pnadc %>% filter(V4013 == "02000")

  saveRDS(dados_pnadc, cache_dados)
}

# Estados (UF) disponíveis na base, para os seletores de Estado
lista_ufs <- sort(unique(dados_pnadc$UF))

# Opções padrão dos pickerInput de Estado (dropdown com seta, igual ao "Ano",
# mas com caixa de marcar em cada item e botões prontos de selecionar/limpar)
picker_opcoes <- pickerOptions(
  actionsBox = TRUE,
  liveSearch = TRUE,
  selectedTextFormat = "count > 3",
  countSelectedText = "{0} estados selecionados",
  deselectAllText = "Limpar seleção",
  selectAllText = "Selecionar todos",
  noneSelectedText = "Nenhum estado selecionado"
)

# Mesma ideia, para o seletor de Trimestre (sem busca, já que são só 4 itens)
picker_opcoes_trimestre <- pickerOptions(
  actionsBox = TRUE,
  selectedTextFormat = "count > 2",
  countSelectedText = "{0} trimestres selecionados",
  deselectAllText = "Limpar seleção",
  selectAllText = "Selecionar todos",
  noneSelectedText = "Nenhum trimestre selecionado"
)

# ---- Mapa do Brasil (contorno dos estados, via API do IBGE) -----
# TODO: se o mapa não carregar, confira com names(mapa_brasil) se a
# coluna de código do estado realmente se chama "codarea" (API do IBGE).
# O contorno é salvo em cache local (dados/_cache_mapa_brasil.rds) na
# primeira vez, para não depender da internet/API em toda abertura do app.
cache_mapa <- file.path(pasta_dados, "_cache_mapa_brasil.rds")

mapa_brasil <- if (file.exists(cache_mapa)) {
  readRDS(cache_mapa)
} else {
  resultado <- tryCatch({
    sf::st_read(
      paste0("https://servicodados.ibge.gov.br/api/v3/malhas/paises/BR",
             "?formato=application/vnd.geo+json&qualidade=minima&intrarregiao=UF"),
      quiet = TRUE
    )
  }, error = function(e) NULL)
  if (!is.null(resultado)) saveRDS(resultado, cache_mapa)
  resultado
}

cod_uf_nome <- c(
  "11" = "Rondônia", "12" = "Acre", "13" = "Amazonas", "14" = "Roraima",
  "15" = "Pará", "16" = "Amapá", "17" = "Tocantins", "21" = "Maranhão",
  "22" = "Piauí", "23" = "Ceará", "24" = "Rio Grande do Norte",
  "25" = "Paraíba", "26" = "Pernambuco", "27" = "Alagoas", "28" = "Sergipe",
  "29" = "Bahia", "31" = "Minas Gerais", "32" = "Espírito Santo",
  "33" = "Rio de Janeiro", "35" = "São Paulo", "41" = "Paraná",
  "42" = "Santa Catarina", "43" = "Rio Grande do Sul",
  "50" = "Mato Grosso do Sul", "51" = "Mato Grosso", "52" = "Goiás",
  "53" = "Distrito Federal"
)

if (!is.null(mapa_brasil) && "codarea" %in% names(mapa_brasil)) {
  mapa_brasil$UF <- cod_uf_nome[as.character(mapa_brasil$codarea)]
}

# ---- Dicionário de códigos da PNAD Contínua -----------------
desc_gerais <- c(
  V2007  = "Sexo",
  V2010  = "Cor ou raça",
  V20082 = "Ano de nascimento (usado para calcular idade)",
  V3001  = "Sabe ler e escrever",
  V3009A = "Grau de escolaridade"
)

desc_saude <- c(
  V4006A = "Motivo de afastamento do trabalho (último ano)"
)

desc_trabalho <- c(
  V4009   = "Quantidade de trabalhos",
  V4010   = "Ocupação (código CBO)",
  V40132A = "Seção da atividade do negócio (CNAE) - igual para todo o setor florestal",
  V4025   = "Contratado como temporário",
  V4029   = "Tem carteira de trabalho assinada",
  V4032   = "Contribui para a previdência social",
  V403311 = "Faixa de rendimento",
  V4039   = "Horas habitualmente trabalhadas por semana",
  V4040   = "Tempo de serviço no trabalho atual"
)

desc_setor <- c(
  "01"    = "Agricultura, pecuária e serviços relacionados",
  "02000" = "Produção florestal - código usado para filtrar esta base"
)

dicionario_pnad <- bind_rows(
  tibble(categoria = "Variável (dados gerais)", codigo = names(desc_gerais),   descricao = unname(desc_gerais)),
  tibble(categoria = "Variável (saúde)",        codigo = names(desc_saude),    descricao = unname(desc_saude)),
  tibble(categoria = "Variável (trabalho)",     codigo = names(desc_trabalho), descricao = unname(desc_trabalho)),
  tibble(categoria = "Setor (CNAE-Domiciliar)", codigo = names(desc_setor),    descricao = unname(desc_setor))
)

# ---- Apoio às abas Análises / Comparações / Mapa --------------
vars_fora_da_analise <- c("V40132A")
vars_numericas <- c("V4039", "V20082")

lista_variaveis <- dicionario_pnad %>%
  filter(categoria != "Setor (CNAE-Domiciliar)",
         !codigo %in% vars_fora_da_analise,
         codigo %in% names(dados_pnadc)) %>%
  { setNames(.$codigo, paste0(.$codigo, " — ", .$descricao)) }

ano_min <- min(dados_pnadc$ano)
ano_max <- max(dados_pnadc$ano)
tri_max <- max(dados_pnadc$trimestre[dados_pnadc$ano == ano_max])

ocupacao_map <- c(
  "1311" = "Dirigentes de produção agropecuária e silvicultura",
  "3143" = "Técnicos florestais",
  "6112" = "Trabalhadores qualificados no cultivo de hortas, viveiros e jardins",
  "6210" = "Trabalhadores florestais qualificados e afins",
  "8341" = "Operadores de máquinas agrícolas e florestais móveis",
  "9215" = "Trabalhadores florestais elementares"
)

mapear_ocupacao <- function(x) {
  x <- as.character(x)
  ifelse(x %in% names(ocupacao_map), ocupacao_map[x], "Outras ocupações")
}

rotulos_categorias <- list(
  V4025 = c("Sim" = "Temporário", "Não" = "Não temporário (CLT)"),
  V4029 = c("Sim" = "Com carteira assinada", "Não" = "Sem carteira assinada")
)

ordem_categorias <- list(
  V403311 = c("1 a [0,5SM]", "[0,5SM]+1 a [1SM]", "[1SM]+1 a [2SM]",
              "[2SM]+1 a [3SM]", "[3SM]+1 a [5SM]", "[5SM]+1 a [10SM]",
              "[10SM]+1 a [20SM]", "[20SM]+1 ou mais"),
  V4040   = c("Menos de 1 mês", "De 1 mês a menos de 1 ano",
              "De 1 ano a menos de 2 anos", "2 anos ou mais"),
  V3009A  = c("Superior - graduação",
              "Regular do ensino médio ou do 2º grau",
              "Educação de jovens e adultos (EJA) ou supletivo do 2º grau",
              "Antigo ginásio (médio 1º ciclo)",
              "Regular do ensino fundamental ou do 1º grau",
              "Antigo primário (elementar)")
)

filtrar_periodo <- function(df, ano_sel, tri_sel) {
  df %>% filter(ano == as.numeric(ano_sel),
                trimestre %in% as.numeric(tri_sel))
}

texto_periodo <- function(ano_sel, tri_sel) {
  tri_sel <- sort(as.numeric(tri_sel))
  if (length(tri_sel) == 1) paste0(ano_sel, ".", tri_sel)
  else paste0(ano_sel, " (trimestres ", paste(tri_sel, collapse = ", "), ")")
}

moda <- function(x) {
  tabela <- table(x)
  as.numeric(names(tabela)[which.max(tabela)])
}

preparar_var <- function(df, var) {
  if (var == "V20082") {
    df %>%
      mutate(valor = suppressWarnings(as.numeric(V20082))) %>%
      filter(!is.na(valor), valor != 9999) %>%
      mutate(valor = ano - valor) %>%
      filter(valor > 0, valor < 100)
  } else if (var %in% vars_numericas) {
    df %>%
      mutate(valor = suppressWarnings(as.numeric(.data[[var]]))) %>%
      filter(!is.na(valor), valor > 0)
  } else if (var == "V4010") {
    df %>%
      filter(!is.na(V4010)) %>%
      mutate(valor = mapear_ocupacao(V4010))
  } else {
    saida <- df %>%
      mutate(valor = as.character(.data[[var]])) %>%
      filter(!is.na(valor), valor != "", valor != "Sem dados")
    if (var %in% names(rotulos_categorias)) {
      saida <- saida %>% mutate(valor = recode(valor, !!!rotulos_categorias[[var]]))
    }
    saida
  }
}

rotulo_variavel <- function(var) {
  if (var == "V20082") return("Idade (anos, aproximada)")
  dicionario_pnad$descricao[match(var, dicionario_pnad$codigo)]
}

agrupar_top <- function(df, max_cat = 8) {
  topo <- df %>% count(valor, sort = TRUE) %>% slice_head(n = max_cat) %>% pull(valor)
  df %>% mutate(valor = ifelse(valor %in% topo, valor, "Outras"))
}

ordenar_categorias <- function(df, var) {
  niveis <- unique(df$valor)
  if (var %in% names(ordem_categorias)) {
    ordem <- ordem_categorias[[var]]
    niveis <- c(intersect(ordem, niveis), setdiff(niveis, ordem))
  } else {
    niveis <- sort(niveis)
  }
  df %>% mutate(valor = factor(valor, levels = niveis))
}

baixar_grafico <- function(nome_fn, plot_reativo, largura = 10, altura = 6) {
  downloadHandler(
    filename = function() paste0(nome_fn(), ".png"),
    content = function(file) {
      g <- plot_reativo() + theme(plot.background = element_rect(fill = "white", colour = NA))
      ggsave(file, plot = g, device = "png", width = largura, height = altura, dpi = 300)
    }
  )
}

cond_categorica <- sprintf("!['%s'].includes(input.an_variavel)",
                           paste(vars_numericas, collapse = "','"))

# -- Apoio só da aba Comparações: trata UMA variável categórica, sem
# amarrar o nome da coluna de saída a "valor" (usado duas vezes: eixo X
# e eixo Y de um mesmo cruzamento) --
rotular_categoria <- function(df, var) {
  if (var == "V4010") {
    df %>% filter(!is.na(V4010)) %>% mutate(.cat = mapear_ocupacao(V4010))
  } else {
    saida <- df %>%
      mutate(.cat = as.character(.data[[var]])) %>%
      filter(!is.na(.cat), .cat != "", .cat != "Sem dados")
    if (var %in% names(rotulos_categorias)) {
      saida <- saida %>% mutate(.cat = recode(.cat, !!!rotulos_categorias[[var]]))
    }
    saida
  }
}

# Prepara duas colunas categóricas (cat_x, cat_y) já agrupadas/ordenadas,
# reaproveitando agrupar_top()/ordenar_categorias() (que operam em "valor")
preparar_cruzamento <- function(df, var_x, var_y) {
  df <- rotular_categoria(df, var_x) %>%
    rename(valor = .cat) %>% agrupar_top() %>% ordenar_categorias(var_x) %>%
    rename(cat_x = valor)
  df <- rotular_categoria(df, var_y) %>%
    rename(valor = .cat) %>% agrupar_top() %>% ordenar_categorias(var_y) %>%
    rename(cat_y = valor)
  df
}

# Mapa de calor genérico entre duas variáveis categóricas
grafico_cruzamento <- function(df, var_x, var_y, inverter) {
  d <- preparar_cruzamento(df, var_x, var_y)
  validate(need(nrow(d) > 0, "Sem dados para os filtros selecionados."))
  if (isTRUE(inverter)) {
    d <- d %>% rename(tmp = cat_x, cat_x = cat_y, cat_y_novo = tmp) %>% rename(cat_y = cat_y_novo)
    lab_x <- rotulo_variavel(var_y); lab_y <- rotulo_variavel(var_x)
  } else {
    lab_x <- rotulo_variavel(var_x); lab_y <- rotulo_variavel(var_y)
  }
  tab <- d %>%
    count(cat_x, cat_y) %>%
    group_by(cat_y) %>%
    mutate(pct = n / sum(n) * 100) %>%
    ungroup()
  ggplot(tab, aes(x = cat_x, y = cat_y, fill = pct)) +
    geom_tile(color = "white", linewidth = 0.6) +
    geom_text(aes(label = round(pct), color = pct > 50), size = 3, fontface = "bold", show.legend = FALSE) +
    scale_color_manual(values = c("TRUE" = "black", "FALSE" = "white")) +
    scale_fill_viridis_c(name = "% dentro de cada coluna") +
    scale_x_discrete(labels = scales::label_wrap(20)) +
    scale_y_discrete(labels = scales::label_wrap(28)) +
    labs(title = paste(lab_x, "×", lab_y), x = lab_x, y = lab_y) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid = element_blank())
}

# Gráfico de colunas (média) entre uma variável numérica e uma categórica
grafico_cruzamento_num <- function(df, var_num, var_cat, inverter) {
  d <- rotular_categoria(df, var_cat) %>%
    rename(valor = .cat) %>% agrupar_top() %>% ordenar_categorias(var_cat) %>%
    rename(cat = valor)
  d <- d %>%
    mutate(num = suppressWarnings(as.numeric(.data[[var_num]]))) %>%
    filter(!is.na(num), num > 0)
  validate(need(nrow(d) > 0, "Sem dados para os filtros selecionados."))
  lab_cat <- rotulo_variavel(var_cat); lab_num <- rotulo_variavel(var_num)

  resumo <- d %>% group_by(cat) %>% summarise(media = mean(num), .groups = "drop")

  p <- ggplot(resumo, aes(x = cat, y = media)) +
    geom_col(fill = "#1267a8") +
    geom_text(aes(label = round(media, 1)), vjust = -0.5, size = 3.5) +
    scale_x_discrete(labels = scales::label_wrap(20)) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
    labs(title = paste(lab_num, "×", lab_cat), x = lab_cat, y = paste("Média -", lab_num)) +
    theme_minimal()
  if (isTRUE(inverter)) p <- p + coord_flip()
  p
}

# ---- 2) Interface (UI) ---------------------------------------
ui <- fluidPage(
  tags$head(tags$style(HTML("
    table.dataTable td, table.dataTable th {
      padding: 2px 8px !important;
      line-height: 1.1 !important;
      font-size: 12px !important;
      white-space: nowrap !important;
    }
    table.dataTable tbody tr:hover { background-color: #eef6ff !important; }
  "))),
  titlePanel("Indicadores do Setor Florestal"),
  navlistPanel(
    widths = c(2, 10),

  # -- Aba 1: Dados --
  tabPanel("Dados",
    sidebarLayout(
      sidebarPanel(
        selectInput("filtro_ano", "Ano:",
                    choices = sort(unique(dados_pnadc$ano), decreasing = TRUE)),
        pickerInput("filtro_trimestre", "Trimestre:",
                    choices = sort(unique(dados_pnadc$trimestre)),
                    selected = sort(unique(dados_pnadc$trimestre)),
                    multiple = TRUE, options = picker_opcoes_trimestre),
        pickerInput("filtro_uf", "Estado (UF):",
                    choices = lista_ufs, selected = lista_ufs, multiple = TRUE,
                    options = picker_opcoes),
        downloadButton("baixar_excel", "Exportar para Excel"),
        br(), br(),
        downloadButton("baixar_dicionario", "Baixar dicionário de códigos")
      ),
      mainPanel(
        DTOutput("tabela_dados", height = "420px"),
        hr(),
        h4("Dicionário de códigos da PNAD Contínua"),
        DTOutput("tabela_dicionario", height = "280px")
      )
    )
  ),

  # -- Aba 2: Análises (gráficos de 1 critério - seletores "an_") --
  tabPanel("Análises",
    sidebarLayout(
      sidebarPanel(
        selectInput("an_variavel", "Variável (código PNAD):",
                    choices = lista_variaveis),
        pickerInput("an_uf", "Estado (UF):",
                    choices = lista_ufs, selected = lista_ufs, multiple = TRUE,
                    options = picker_opcoes),
        helpText("A variável e o(s) estado(s) escolhidos acima valem para os dois blocos abaixo."),

        wellPanel(
          h5(strong("Evolução por período")),
          sliderInput("an_periodo", "Intervalo de anos:",
                      min = ano_min, max = ano_max,
                      value = c(max(ano_min, ano_max - 1), ano_max),
                      step = 1, sep = ""),
          conditionalPanel(
            condition = cond_categorica,
            radioButtons("an_medida", "Medida:",
                         choices = c("Porcentagem" = "pct", "Número de registros" = "n"),
                         inline = TRUE)
          ),
          conditionalPanel(
            condition = "input.an_variavel == 'V4039'",
            checkboxInput("an_dif40", "Mostrar jornada como diferença em relação a 40 h", FALSE)
          )
        ),

        wellPanel(
          h5(strong("Panorama de um período")),
          selectInput("an_ano", "Ano:",
                      choices = sort(unique(dados_pnadc$ano), decreasing = TRUE),
                      selected = ano_max),
          pickerInput("an_trimestre", "Trimestre(s):",
                      choices = sort(unique(dados_pnadc$trimestre)),
                      selected = sort(unique(dados_pnadc$trimestre)),
                      multiple = TRUE, options = picker_opcoes_trimestre),
          conditionalPanel(
            condition = cond_categorica,
            radioButtons("an_tipo", "Tipo de gráfico:",
                         choices = c("Barras", "Pizza"), inline = TRUE)
          )
        ),

        wellPanel(
          h5(strong("Mapa por estado")),
          selectInput("mapa_ano", "Ano:",
                      choices = sort(unique(dados_pnadc$ano), decreasing = TRUE),
                      selected = ano_max),
          pickerInput("mapa_trimestre", "Trimestre(s):",
                      choices = sort(unique(dados_pnadc$trimestre)),
                      selected = sort(unique(dados_pnadc$trimestre)),
                      multiple = TRUE, options = picker_opcoes_trimestre),
          uiOutput("mapa_categoria_ui"),
          helpText("Variáveis numéricas mostram a média por estado.",
                   "Variáveis categóricas mostram a % da categoria",
                   "escolhida acima em cada estado.")
        )
      ),
      mainPanel(
        h4("Evolução por período"),
        plotOutput("grafico_evolucao", height = "340px"),
        downloadButton("baixar_evolucao", "Baixar gráfico (PNG)", class = "btn-sm"),
        hr(),
        h4("Panorama do(s) trimestre(s) selecionado(s)"),
        plotOutput("grafico_periodo", height = "340px"),
        downloadButton("baixar_periodo", "Baixar gráfico (PNG)", class = "btn-sm"),
        hr(),
        h4("Mapa por estado"),
        leafletOutput("mapa_brasil", height = "480px"),
        br(),
        helpText("Valores calculados sobre os registros da amostra da",
                 "PNAD Contínua, sem aplicar pesos amostrais.")
      )
    )
  ),

  # -- Aba 3: Comparações (gráficos cruzando 2 critérios - seletores "cmp_") --
  tabPanel("Comparações",
    sidebarLayout(
      sidebarPanel(
        selectInput("cmp_tipo", "Tipo de comparação:",
          choices = c(
            "Cargos × Gênero"                  = "cargos_genero",
            "Cargos × Cor"                      = "cargos_cor",
            "Gênero × Faixa de rendimento"       = "genero_rendimento",
            "Cor × Faixa de rendimento"          = "cor_rendimento",
            "Horas trabalhadas × Gênero"         = "horas_genero",
            "Horas trabalhadas × Cor"            = "horas_cor",
            "Cargos × Faixa de rendimento"       = "cargos_rendimento"
          )),
        hr(),
        selectInput("cmp_ano", "Ano:",
                    choices = sort(unique(dados_pnadc$ano), decreasing = TRUE),
                    selected = ano_max),
        pickerInput("cmp_trimestre", "Trimestre(s):",
                    choices = sort(unique(dados_pnadc$trimestre)),
                    selected = sort(unique(dados_pnadc$trimestre)),
                    multiple = TRUE, options = picker_opcoes_trimestre),
        pickerInput("cmp_uf", "Estado (UF):",
                    choices = lista_ufs, selected = lista_ufs, multiple = TRUE,
                    options = picker_opcoes)
      ),
      mainPanel(
        plotOutput("grafico_comparacao", height = "440px"),
        downloadButton("baixar_comparacao", "Baixar gráfico (PNG)", class = "btn-sm"),
        br(), br(),
        helpText("Valores calculados sobre os registros da amostra da",
                 "PNAD Contínua, sem aplicar pesos amostrais.")
      )
    )
  )
  )
)

# ---- 3) Lógica do app (server) --------------------------------
server <- function(input, output, session) {

  # "Selecionar todos" / "Limpar seleção" agora é o actionsBox embutido no
  # próprio pickerInput — não precisa mais de observeEvent para isso.

  dados_filtrados <- reactive({
    req(input$filtro_trimestre)
    validate(need(length(input$filtro_uf) > 0, "Selecione pelo menos um estado."))
    dados_pnadc %>%
      filter(ano == input$filtro_ano,
             trimestre %in% input$filtro_trimestre,
             UF %in% input$filtro_uf)
  })

  # -- Aba Dados --
  output$tabela_dados <- renderDT({
    datatable(dados_filtrados(),
              class = "compact stripe hover",
              options = list(pageLength = 20, scrollY = "350px", scrollCollapse = TRUE,
                              scrollX = TRUE, dom = "tip", autoWidth = TRUE))
  })

  output$baixar_excel <- downloadHandler(
    filename = function() {
      trimestres_txt <- paste(sort(input$filtro_trimestre), collapse = "-")
      uf_txt <- if (length(input$filtro_uf) == length(lista_ufs)) "BR" else paste(input$filtro_uf, collapse = "-")
      paste0("indicadores_florestal_", uf_txt, "_", input$filtro_ano, "_T", trimestres_txt, ".xlsx")
    },
    content = function(file) write_xlsx(dados_filtrados(), file)
  )

  output$tabela_dicionario <- renderDT({
    datatable(dicionario_pnad,
              class = "compact stripe hover",
              colnames = c("Categoria" = "categoria", "Código" = "codigo", "Descrição" = "descricao"),
              options = list(pageLength = 20, scrollY = "220px", scrollCollapse = TRUE,
                              scrollX = TRUE, dom = "tip", autoWidth = TRUE,
                              columnDefs = list(
                                list(width = "150px", targets = 0),
                                list(width = "90px",  targets = 1),
                                list(width = "480px", targets = 2)
                              )))
  })

  output$baixar_dicionario <- downloadHandler(
    filename = function() "dicionario_codigos_pnad.xlsx",
    content = function(file) write_xlsx(dicionario_pnad, file)
  )

  # -- Aba Análises --
  base_var <- reactive({
    req(input$an_variavel)
    validate(need(input$an_variavel %in% names(dados_pnadc),
                  "Variável não encontrada na base de dados."))
    validate(need(length(input$an_uf) > 0, "Selecione pelo menos um estado."))
    dados_pnadc %>% filter(UF %in% input$an_uf) %>% preparar_var(input$an_variavel)
  })

  base_evolucao <- reactive({
    req(input$an_periodo)
    df <- base_var() %>%
      filter(ano >= input$an_periodo[1], ano <= input$an_periodo[2])
    chaves <- sort(unique(df$ano * 10 + df$trimestre))
    df %>% mutate(periodo = factor(paste0(ano, ".", trimestre),
                                   levels = paste0(chaves %/% 10, ".", chaves %% 10)))
  })

  base_panorama <- reactive({
    req(input$an_ano)
    validate(need(length(input$an_trimestre) > 0, "Marque pelo menos um trimestre."))
    filtrar_periodo(base_var(), input$an_ano, input$an_trimestre)
  })

  plot_evolucao <- reactive({
    var <- input$an_variavel
    df <- base_evolucao()
    validate(need(nrow(df) > 0, "Sem dados para o intervalo selecionado."))
    rotulo <- rotulo_variavel(var)
    n_per <- nlevels(df$periodo)
    passo <- max(1, ceiling(n_per / 16))
    mostrar_rotulos <- n_per <= 12

    if (var == "V20082") {
      resumo <- bind_rows(
        df %>% group_by(periodo) %>% summarise(y = mean(valor), .groups = "drop") %>% mutate(estat = "Média"),
        df %>% group_by(periodo) %>% summarise(y = median(valor), .groups = "drop") %>% mutate(estat = "Mediana"),
        df %>% group_by(periodo) %>% summarise(y = moda(valor), .groups = "drop") %>% mutate(estat = "Moda")
      )
      p <- ggplot(resumo, aes(x = periodo, y = y, color = estat, group = estat)) +
        geom_line(linewidth = 1) +
        geom_point(size = 2) +
        scale_color_manual(values = c("Média" = "#1267a8", "Mediana" = "#e08a1e", "Moda" = "#2a9d4b")) +
        labs(y = "Idade (anos)", color = NULL)
      if (mostrar_rotulos) {
        p <- p + geom_text(aes(label = round(y, 1)), vjust = -0.8, size = 3, show.legend = FALSE)
      }

    } else if (var == "V4039") {
      resumo <- df %>% group_by(periodo) %>% summarise(y = mean(valor), .groups = "drop")
      if (isTRUE(input$an_dif40)) {
        resumo <- resumo %>% mutate(y = y - 40)
        p <- ggplot(resumo, aes(x = periodo, y = y, group = 1)) +
          geom_hline(yintercept = 0, linetype = "dashed", color = "#1267a8") +
          geom_line(color = "#1267a8", linewidth = 1) +
          geom_point(color = "#1267a8", size = 2) +
          labs(y = "Diferença em relação a 40 horas")
        if (mostrar_rotulos) p <- p + geom_text(aes(label = sprintf("%+.2f h", y)), vjust = -0.8, size = 3)
      } else {
        p <- ggplot(resumo, aes(x = periodo, y = y, group = 1)) +
          geom_hline(yintercept = c(40, 44), linetype = "dashed", color = "grey50") +
          geom_line(color = "#1267a8", linewidth = 1) +
          geom_point(color = "#1267a8", size = 2) +
          labs(y = "Jornada média semanal (horas)",
               subtitle = "Linhas tracejadas: 40 h (referência) e 44 h (limite legal)")
        if (mostrar_rotulos) p <- p + geom_text(aes(label = sprintf("%.2f h", y)), vjust = -0.8, size = 3)
      }

    } else {
      usa_pct <- identical(input$an_medida, "pct")
      resumo <- df %>%
        agrupar_top() %>%
        ordenar_categorias(var) %>%
        count(periodo, valor) %>%
        group_by(periodo) %>%
        mutate(pct = n / sum(n) * 100) %>%
        ungroup()
      resumo$y   <- if (usa_pct) resumo$pct else resumo$n
      resumo$rot <- if (usa_pct) paste0(round(resumo$pct, 1), "%") else as.character(resumo$n)
      p <- ggplot(resumo, aes(x = periodo, y = y, color = valor, group = valor)) +
        geom_line(linewidth = 1) +
        geom_point(size = 2) +
        scale_color_viridis_d(end = 0.9) +
        labs(y = if (usa_pct) "% dos registros" else "Número de registros", color = NULL)
      if (usa_pct) p <- p + scale_y_continuous(labels = function(v) paste0(round(v), "%"))
      if (mostrar_rotulos) p <- p + geom_text(aes(label = rot), vjust = -0.8, size = 3, show.legend = FALSE)
    }

    p +
      scale_x_discrete(breaks = levels(df$periodo)[seq(1, n_per, by = passo)]) +
      labs(title = paste("Evolução por período -", rotulo), x = "Período (ano.trimestre)") +
      theme_minimal() +
      theme(legend.position = "bottom", axis.text.x = element_text(angle = 45, hjust = 1))
  })

  plot_periodo <- reactive({
    var <- input$an_variavel
    df <- base_panorama()
    validate(need(nrow(df) > 0, "Sem dados para o ano e trimestre selecionados."))
    rotulo <- rotulo_variavel(var)
    titulo <- paste0(rotulo, " - ", texto_periodo(input$an_ano, input$an_trimestre))

    if (var == "V20082") {
      # Idade: um ponto por funcionário (jitter), média marcada em vermelho,
      # igual ao gráfico do relatório da IC (Figura 15)
      media_idade <- mean(df$valor)
      d_pontos <- df %>% mutate(tipo = "Funcionários")
      d_media  <- tibble(valor = media_idade, tipo = "Média de idade")
      set.seed(1)  # mesmo espalhamento (jitter) toda vez que o gráfico é gerado
      p <- ggplot() +
        geom_jitter(data = d_pontos, aes(x = valor, y = 0, color = tipo),
                    height = 1, width = 0.3, size = 2, alpha = 0.7) +
        geom_rug(data = d_pontos, aes(x = valor), sides = "b", color = "grey60", linewidth = 0.3) +
        geom_point(data = d_media, aes(x = valor, y = 0, color = tipo), size = 3) +
        scale_color_manual(values = c("Funcionários" = "grey50", "Média de idade" = "red"), name = NULL) +
        labs(x = "Idade dos funcionários", y = NULL) +
        theme_minimal() +
        theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(),
              legend.position = "bottom")

    } else if (var == "V4039") {
      # Horas trabalhadas: histograma em barras
      media <- mean(df$valor)
      p <- ggplot(df, aes(x = valor)) +
        geom_histogram(binwidth = 5, fill = "#1267a8", color = "white", boundary = 0) +
        geom_vline(xintercept = media, linetype = "dashed", color = "black") +
        labs(x = "Horas semanais", y = "Registros",
             subtitle = paste0("Média = ", round(media, 2), " h (linha tracejada)")) +
        theme_minimal()

    } else {
      resumo <- df %>%
        agrupar_top() %>%
        ordenar_categorias(var) %>%
        count(valor) %>%
        mutate(pct = n / sum(n) * 100)

      if (identical(input$an_tipo, "Pizza")) {
        p <- ggplot(resumo, aes(x = "", y = n, fill = valor)) +
          geom_col(width = 1, color = "black") +
          coord_polar(theta = "y") +
          geom_text(aes(label = paste0(round(pct, 1), "%")),
                    position = position_stack(vjust = 0.5), size = 4) +
          scale_fill_viridis_d(end = 0.9) +
          labs(fill = NULL) +
          theme_void() +
          theme(legend.position = "right")
      } else {
        if (var %in% names(ordem_categorias)) {
          resumo$valor <- factor(resumo$valor, levels = rev(levels(resumo$valor)))
        } else {
          resumo$valor <- reorder(resumo$valor, resumo$pct)
        }
        p <- ggplot(resumo, aes(x = valor, y = pct)) +
          geom_col(fill = "#1267a8") +
          geom_text(aes(label = paste0(round(pct, 1), "%")), hjust = -0.1, size = 3.5) +
          coord_flip() +
          scale_x_discrete(labels = scales::label_wrap(35)) +
          scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
          labs(x = NULL, y = "% dos registros") +
          theme_minimal()
      }
    }

    p + labs(title = titulo) + theme(plot.title = element_text(size = 12, hjust = 0.5))
  })

  output$grafico_evolucao <- renderPlot({ plot_evolucao() })
  output$grafico_periodo  <- renderPlot({ plot_periodo() })

  sufixo_tri <- function(x) paste(sort(x), collapse = "")

  output$baixar_evolucao <- baixar_grafico(
    function() paste0("evolucao_", input$an_variavel, "_", input$an_periodo[1], "-", input$an_periodo[2]),
    plot_evolucao, largura = 10, altura = 6)

  output$baixar_periodo <- baixar_grafico(
    function() paste0("panorama_", input$an_variavel, "_", input$an_ano, "_T", sufixo_tri(input$an_trimestre)),
    plot_periodo, largura = 9, altura = 6)

  # -- Aba Comparações --
  plot_comparacao <- reactive({
    req(input$cmp_ano, input$cmp_tipo)
    validate(need(length(input$cmp_trimestre) > 0, "Marque pelo menos um trimestre."))
    validate(need(length(input$cmp_uf) > 0, "Selecione pelo menos um estado."))
    df <- filtrar_periodo(dados_pnadc, input$cmp_ano, input$cmp_trimestre) %>%
      filter(UF %in% input$cmp_uf)
    p <- switch(input$cmp_tipo,
      "cargos_genero"      = grafico_cruzamento(df, "V4010", "V2007", FALSE),
      "cargos_cor"         = grafico_cruzamento(df, "V4010", "V2010", FALSE),
      "genero_rendimento"  = grafico_cruzamento(df, "V2007", "V403311", FALSE),
      "cor_rendimento"     = grafico_cruzamento(df, "V2010", "V403311", FALSE),
      "horas_genero"       = grafico_cruzamento_num(df, "V4039", "V2007", FALSE),
      "horas_cor"          = grafico_cruzamento_num(df, "V4039", "V2010", FALSE),
      "cargos_rendimento"  = grafico_cruzamento(df, "V4010", "V403311", FALSE)
    )
    p + labs(subtitle = texto_periodo(input$cmp_ano, input$cmp_trimestre)) +
      theme(plot.title = element_text(size = 12, hjust = 0.5))
  })

  output$grafico_comparacao <- renderPlot({ plot_comparacao() })

  output$baixar_comparacao <- baixar_grafico(
    function() paste0("comparacao_", input$cmp_tipo, "_", input$cmp_ano, "_T", sufixo_tri(input$cmp_trimestre)),
    plot_comparacao, largura = 10, altura = 7)

  # -- Mapa (dentro da aba Análises, usa a mesma an_variavel) --

  # Seletor de categoria só aparece quando a variável é categórica; as
  # opções mudam sozinhas conforme a variável escolhida em an_variavel.
  output$mapa_categoria_ui <- renderUI({
    var <- input$an_variavel
    req(var)
    if (var %in% c(vars_numericas, "V20082")) return(NULL)
    cats <- rotular_categoria(dados_pnadc, var) %>%
      count(.cat, sort = TRUE) %>% pull(.cat)
    selectInput("mapa_categoria", "Categoria de interesse:",
                choices = cats, selected = cats[1])
  })

  output$mapa_brasil <- renderLeaflet({
    validate(need(!is.null(mapa_brasil), paste(
      "Não foi possível carregar o contorno dos estados (API do IBGE",
      "fora do ar ou sem conexão com a internet).")))
    validate(need(length(input$mapa_trimestre) > 0, "Marque pelo menos um trimestre."))
    req(input$mapa_ano, input$an_variavel)

    df <- filtrar_periodo(dados_pnadc, input$mapa_ano, input$mapa_trimestre)
    var <- input$an_variavel

    if (var %in% c(vars_numericas, "V20082")) {
      resumo <- preparar_var(df, var) %>%
        group_by(UF) %>% summarise(valor = mean(valor), .groups = "drop")
      legenda <- paste("Média -", rotulo_variavel(var))
      rotulo_val <- function(v) round(v, 1)
    } else {
      req(input$mapa_categoria)
      resumo <- rotular_categoria(df, var) %>%
        group_by(UF) %>%
        summarise(valor = mean(.cat == input$mapa_categoria, na.rm = TRUE) * 100, .groups = "drop")
      legenda <- paste0("% ", input$mapa_categoria)
      rotulo_val <- function(v) paste0(round(v, 1), "%")
    }

    mapa_dados <- mapa_brasil %>% left_join(resumo, by = "UF")
    pal <- colorNumeric("viridis", mapa_dados$valor, na.color = "#f0f0f0")

    leaflet(mapa_dados) %>%
      addProviderTiles("Esri.WorldGrayCanvas") %>%
      addPolygons(
        fillColor = ~pal(valor), fillOpacity = 0.8, color = "white", weight = 1,
        label = ~paste0(UF, ": ", ifelse(is.na(valor), "sem dados", rotulo_val(valor))),
        highlightOptions = highlightOptions(weight = 3, color = "#333", bringToFront = TRUE)
      ) %>%
      addLegend(pal = pal, values = ~valor, title = legenda, position = "bottomright")
  })
}

shinyApp(ui, server)
