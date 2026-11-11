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

## Documentação
Cada implementação concluída é registrada nas notas do projeto (Obsidian: "Log de implementações"), com o link do Pull Request.

## Créditos
O DREAVON é derivado do [Plasdria](https://github.com/PietroAlexandria/Plasdria) (MIT). Mantenha os avisos de copyright do [LICENSE](LICENSE).
