# Dashboard de Indicadores do Setor Florestal

Painel web interativo, feito em **R/Shiny**, que transforma os microdados públicos da **PNAD Contínua (IBGE)** em indicadores sociais e econômicos sobre o trabalho no setor florestal brasileiro.

Projeto desenvolvido como meu **Trabalho de Conclusão de Curso** no Bacharelado Interdisciplinar em Inovação, Ciência e Tecnologia (BICT) da UFLA, no LEMAF — Laboratório de Ciência de Dados em Manejo Florestal (DCF/UFLA).

🔗 **Ver o dashboard online:** [pnadlemaf.shinyapps.io/indicadores-florestal-mg](https://pnadlemaf.shinyapps.io/indicadores-florestal-mg/)

> Este repositório é a minha cópia (fork) da versão que desenvolvi. A versão oficial, mantida pelo laboratório, está em [pnadlemaflemaf/dashboard-setor-florestal](https://github.com/pnadlemaflemaf/dashboard-setor-florestal).

![Aba Dados](COLE-AQUI-O-PRINT-DA-ABA-DADOS.png)

## O problema

Os dados da PNAD Contínua são públicos, mas difíceis de usar: são arquivos grandes, com códigos e variáveis que exigem conhecimento técnico para filtrar e interpretar. O objetivo do projeto foi tornar essas informações **acessíveis para quem não programa**, em uma página web de fácil consulta.

## O que o dashboard faz

- **Dados:** tabelas filtráveis com os indicadores do setor florestal e exportação para Excel
- **Análises:** gráficos com a evolução dos indicadores ao longo dos trimestres
- **Sobre a PNAD Contínua:** explicação da fonte dos dados e de como interpretá-los
- **Laboratório:** apresentação do LEMAF e dos projetos de pesquisa

O setor florestal é identificado nos microdados pela classificação de atividade econômica (CNAE — Divisão 02, Produção florestal). A base cobre **58 trimestres, de 2012 a 2026**.

![Aba Análises](COLE-AQUI-O-PRINT-DA-ABA-ANALISES.png)

## Tecnologias

- **R** e **Shiny** para a aplicação web
- **PNADcIBGE** para importar os microdados do IBGE
- **dplyr** e **tibble** para tratamento dos dados
- **ggplot2** para os gráficos e **DT** para as tabelas interativas
- **writexl** para exportação em Excel
- **shinyapps.io** para publicação

## Meu papel

- Desenvolvi o aplicativo do zero, aprendendo R e Shiny durante o projeto
- Tratei e organizei os microdados da PNAD Contínua para o setor florestal
- Estruturei a navegação e o visual a partir de um protótipo validado com a orientação
- Publiquei o dashboard no shinyapps.io
- Escrevi a documentação para que a equipe do laboratório consiga manter e atualizar o projeto

## Como rodar localmente

1. Instale o [R](https://cran.r-project.org) e o [RStudio](https://posit.co/download/rstudio-desktop/).
2. No console do R, instale os pacotes:
   ```r
   install.packages(c("shiny", "dplyr", "DT", "ggplot2", "writexl", "readxl", "tibble", "shinyWidgets"))
   ```
3. Clone o repositório. Os dados já vêm junto, mas a pasta `dados/` passa de 1 GB.
4. Abra o `app.R` no RStudio e clique em **Run App**.

A primeira execução é mais lenta, porque o app lê todos os arquivos e cria um cache.

## Orientação

- Orientadora: Profa. Carolina Souza Jarochinski Dellú (DCF/UFLA)
- Coorientador: Guilherme Ribeiro Aguiar (DCF/UFLA)

## Autora

**Ana Carolina Cesar Ambrizi** · [LinkedIn](https://linkedin.com/in/ana-carolina-ambrizi) · [GitHub](https://github.com/acarolinaambrizi)
