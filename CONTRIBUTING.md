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
- **SemVer** (`MAJOR.MINOR.PATCH`): `PATCH` para correções, `MINOR` para recursos novos que não quebram nada, `MAJOR` para mudanças incompatíveis (por exemplo, configurações que deixam de valer).
- **Número único:** `project(DREAVON VERSION X.Y.Z)` no `CMakeLists.txt`. O `package/metadata.json` precisa ter o mesmo número (`KPlugin.Version`); o CMake confere e para o build se divergirem. O app mostra a versão em Configurações > Sobre.
- **CHANGELOG:** toda mudança relevante entra em `## [Não lançado]` no [CHANGELOG.md](CHANGELOG.md) (formato Keep a Changelog), no mesmo PR da mudança.
- **Lançar uma versão:**
  1. criar a branch `release/X.Y.Z`;
  2. trocar o número nos dois arquivos;
  3. mover `[Não lançado]` para `## [X.Y.Z] - AAAA-MM-DD`;
  4. escrever as notas em `docs/releases/vX.Y.Z.md`;
  5. fazer a auditoria de privacidade (sem chaves, caminhos pessoais nem dados reais; ver diário 11).

  Depois do merge, o autor cria a tag `vX.Y.Z` na `main` e o GitHub Release com as notas.

## Documentação
Cada implementação concluída é registrada nas notas do projeto (Obsidian: "Log de implementações"), com o link do Pull Request.

## Claude Code
A configuração compartilhada fica em `.claude/`:
- `.claude/settings.json`: os plugins usados no projeto (`claude-mem`, `postman`, `claude-code-setup`), só por referência aos marketplaces. Ao abrir o repositório, o Claude Code oferece instalá-los.
- `.claude/skills/`: cópias das skills `design-system` e `task-observer`, com as licenças originais (ver `.claude/skills/README.md`).

Não versione `settings.local.json`, credenciais nem variáveis de ambiente: o `.gitignore` já deixa de fora tudo o que não for esses dois itens.

## Créditos
O DREAVON é derivado do [Plasdria](https://github.com/PietroAlexandria/Plasdria) (MIT). Mantenha os avisos de copyright do [LICENSE](LICENSE).
