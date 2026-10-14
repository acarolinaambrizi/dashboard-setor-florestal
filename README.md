# Dashboard — Indicadores do Setor Florestal (PNAD Contínua)

Dashboard em Shiny que traduz dados da PNAD Contínua (IBGE) em indicadores
sociais e econômicos do setor florestal brasileiro. Desenvolvido como parte
de um Trabalho de Conclusão de Curso (TCC) e mantido pelo LEMAF
(Laboratório de Estudos e Projetos em Manejo Florestal — DCF/UFLA).

**App publicado:** https://pnadlemaf.shinyapps.io/indicadores-florestal-mg/

---

## Os dados ficam neste mesmo repositório

Diferente do que costuma ser recomendado para bases muito grandes, aqui os
`.xlsx` da PNAD **ficam dentro da pasta `dados/`, versionados no GitHub
junto com o código** — nenhum arquivo individual passa de 100MB (o limite
do GitHub), então não há problema técnico em mantê-los juntos. Isso
simplifica a vida de quem for manter o projeto: cloná-lo já traz tudo.

Se os dados da PNAD forem atualizados (novo trimestre, por exemplo), a
pessoa responsável deve gerar o novo `.xlsx` (script de importação, feito
com o pacote `PNADcIBGE`), colocar dentro de `dados/` e publicar a mudança
pelo GitHub Desktop, do mesmo jeito que uma mudança de código (ver seção
"Como atualizar o código", abaixo).

**Se no futuro a pasta `dados/` crescer muito** (se aproximando de ~1GB no
total), vale reconsiderar mover os dados para uma pasta compartilhada do
laboratório (Drive/OneDrive) e ajustar o `.gitignore` — mas não é o caso
agora.

---

## Estrutura deste repositório

```
.
├── app.R                  ← o dashboard em si (Shiny)
├── documentacao_app.md    ← como o código funciona por dentro
├── guia_funcoes.md        ← explicação das funções usadas (bom para quem está aprendendo R/Shiny)
├── dados/                 ← os .xlsx da PNAD e o cache .rds, versionados aqui mesmo
└── .gitignore             ← impede que arquivos locais (específicos de cada PC) sejam versionados
```

---

## Como rodar o app localmente

1. Instale o R e o RStudio, se ainda não tiver.
2. Instale os pacotes necessários (uma vez só, no console do R):
   ```r
   install.packages(c("shiny", "dplyr", "DT", "ggplot2", "writexl",
                       "readxl", "tibble", "leaflet", "sf", "shinyWidgets"))
   ```
3. Clone este repositório (ver seção "Como atualizar o código", abaixo) — os
   dados já vêm juntos, dentro de `dados/`.
4. Abra `app.R` no RStudio e clique em **Run App** (ou rode `shiny::runApp()`
   com a pasta do projeto como diretório de trabalho).

Na primeira vez, o app vai demorar um pouco mais (lendo todos os `.xlsx` e
criando um cache). Nas próximas vezes, abre bem mais rápido.

---

## Como atualizar o código (sem usar linha de comando)

Recomendado: **GitHub Desktop** (https://desktop.github.com/) — interface
visual, não precisa saber comandos de git.

1. Instale o GitHub Desktop e entre com a conta do GitHub do LEMAF.
2. **File > Clone repository** e escolha este repositório — ele baixa uma
   cópia para o seu computador.
3. Edite o `app.R` normalmente no RStudio (ou o `.md` de documentação, se
   for o caso) e salve.
4. Volte para o GitHub Desktop: as mudanças aparecem listadas
   automaticamente. Escreva uma frase curta dizendo o que mudou, clique em
   **Commit to main** e depois em **Push origin**.
5. Pronto — a mudança já está salva no histórico do GitHub, visível para
   qualquer pessoa do laboratório.

Isso **não publica a mudança no app ao vivo** — isso é um passo separado
(próxima seção).

---

## Como publicar (deploy) a mudança no shinyapps.io

1. Pegue (ou peça) as credenciais da conta shinyapps.io do laboratório —
   usuário **pnadlemaf**. Veja em `Account > Tokens` no painel do
   shinyapps.io, e rode uma vez:
   ```r
   rsconnect::setAccountInfo(name = "pnadlemaf", token = "...", secret = "...")
   ```
2. Com a pasta do projeto como diretório de trabalho (confirme com
   `getwd()`), rode:
   ```r
   rsconnect::deployApp(appName = "indicadores-florestal-mg")
   ```
3. Isso atualiza o app que já está publicado — a URL não muda
   (`pnadlemaf.shinyapps.io/indicadores-florestal-mg/`).

**Plano gratuito do shinyapps.io:** 5 apps e 25 horas ativas por mês. Se
precisar de mais, é só avisar a pessoa responsável pela conta.

---

## Dúvidas / contato

Projeto desenvolvido originalmente por Ana Carolina Cesar Ambrizi (TCC —
BICT/UFLA). Para dúvidas sobre o funcionamento do código, comece por
`documentacao_app.md` e `guia_funcoes.md` neste repositório.
