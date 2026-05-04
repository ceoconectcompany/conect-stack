# Conect Installer Modular

Estrutura pronta para o repositório `ceoconectcompany/conect-stack`.

## Como usar no PC

1. Copie tudo desta pasta para `C:\Users\Cristiane\Downloads\pendrive dev`.
2. Rode `atualizar-github.bat` sempre que mexer nos templates.

## Como usar na VPS

```bash
export GITHUB_TOKEN="SEU_TOKEN_AQUI"
bash <(curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" https://raw.githubusercontent.com/ceoconectcompany/conect-stack/main/install.sh)
```

O installer lista apenas pastas dentro de `templates/` que possuem `manifest.json`.
Arquivos de docs, SQL, checklist e TXT não aparecem como templates.

## Templates incluídos

- Imobiliária
- Estética Automotiva
