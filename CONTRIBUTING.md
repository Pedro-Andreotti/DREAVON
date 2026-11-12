# Contribuindo com o DREAVON

Convenção de trabalho com branches, pensada para um projeto pessoal em que mais de uma sessão (VS Code, Claude na nuvem) pode mexer no código.

## Regras
- A `main` fica sempre estável. Só entra nela o que foi testado.
- Cada etapa do plano ([docs/windows-port.md](docs/windows-port.md)) vira uma branch própria, criada a partir da `main` atualizada.
- O trabalho entra na `main` por Pull Request, com *squash merge* (um commit por etapa).
- Quem terminar uma alteração faz commit e push; quem for começar faz `git pull` antes.

## Nomes de branch
| Prefixo | Uso | Exemplo |
| --- | --- | --- |
| `feat/` | funcionalidade ou etapa do port | `feat/cmake-build-windows` |
| `fix/` | correção de erro | `fix/leitura-memoria` |
| `docs/` | só documentação | `docs/contributing` |
| `chore/` | ajustes de build, dependências, limpeza | `chore/gitignore-windows` |
| `perf/` | desempenho | `perf/uso-de-cpu` |
| `release/` | preparação de uma versão | `release/1.0.0` |

## Fluxo
```bash
git switch main && git pull
git switch -c feat/nome-da-etapa
# ... alterações e commits ...
git push -u origin feat/nome-da-etapa
# abrir o Pull Request no GitHub, revisar o diff, fazer o squash merge
git switch main && git pull
git branch -d feat/nome-da-etapa
```

## Commits
Mensagens curtas, em português, no imperativo ou descrevendo a mudança (por exemplo, "Isola o D-Bus atrás de Q_OS_LINUX"). Uma mudança lógica por commit.

## Versões
O DREAVON segue o Versionamento Semântico (`MAJOR.MINOR.PATCH`):

| Mudança | Qual número sobe | Exemplo a partir de 1.0.0 |
| --- | --- | --- |
| Recurso novo | o do meio (MINOR), e o último volta a 0 | 1.1.0, depois 1.2.0 |
| Correção | o último (PATCH) | 1.0.1 |
| Mudança que quebra configurações salvas ou o QML | o primeiro (MAJOR), e os outros voltam a 0 | 2.0.0 |

- **Uma versão por release, não por PR.** PRs só de documentação, limpeza ou build (`docs/`, `chore/`) não sobem a versão.
- **O PR do recurso (ou da correção) já sobe a versão:**
  - troca o número em `project(DREAVON VERSION X.Y.Z)` no `CMakeLists.txt` e em `KPlugin.Version` no `package/metadata.json`; o CMake confere os dois e para o build se divergirem;
  - registra a mudança no [CHANGELOG.md](CHANGELOG.md), numa seção `## [X.Y.Z] - AAAA-MM-DD` (formato Keep a Changelog).
- **Mais de um PR para a mesma versão** (por exemplo, um recurso dividido em partes): só o primeiro sobe o número; os seguintes acrescentam itens à mesma seção do CHANGELOG.
- **Depois do merge na `main`:** o autor cria a tag `vX.Y.Z` e o GitHub Release, com as notas em `docs/releases/vX.Y.Z.md`. Antes, faça a auditoria de privacidade (sem chaves, caminhos pessoais nem dados reais; ver o diário 11).
- O app mostra a versão em Configurações > Sobre.

## Documentação
Cada implementação concluída é registrada nas notas do projeto (Obsidian: "Log de implementações"), com o link do Pull Request.

## Claude Code
A configuração compartilhada fica em `.claude/`:
- `.claude/settings.json`: os plugins usados no projeto (`claude-mem`, `postman`, `claude-code-setup`), só por referência aos marketplaces. Ao abrir o repositório, o Claude Code oferece instalá-los.
- `.claude/skills/`: cópias das skills `design-system` e `task-observer`, com as licenças originais (ver `.claude/skills/README.md`).

Não versione `settings.local.json`, credenciais nem variáveis de ambiente: o `.gitignore` já deixa de fora tudo o que não for esses dois itens.

## Créditos
O DREAVON é derivado do [Plasdria](https://github.com/PietroAlexandria/Plasdria) (MIT). Mantenha os avisos de copyright do [LICENSE](LICENSE).
