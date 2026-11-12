# Como publicar uma nova versão

## Visão geral

- **CI** (`.github/workflows/ci.yml`): a cada envio para `main`, roda
  análise, testes e gera um APK de teste (assinado com chave de debug
  descartável), disponível em Actions → artefato `all-apk-de-teste`.
- **Release** (`.github/workflows/release.yml`): ao enviar uma tag `vX.Y.Z`,
  pega os APKs da pasta `vX.Y.Z/` do ramo `distribuicao`, confere o
  SHA-256 e cria a Release pública.
- O APK de produção é assinado **no computador do proprietário**. A chave
  nunca vai para o GitHub (`*.jks`, `*.keystore` e `key.properties` estão
  no `.gitignore`).

## Chave de assinatura

- Arquivo: `aplicativo-all-release.jks` (PKCS12, RSA 4096, válida até 2126).
- Fica fora do repositório, numa pasta `assinatura/` ao lado do projeto,
  com o `key.properties` (senha) e um LEIA-ME.
- Impressões digitais do certificado:
  - SHA-256 `DA:04:16:40:6D:56:29:46:FB:77:BB:61:11:8C:2A:AD:E7:94:0A:E5:3D:99:96:3F:6D:F8:D3:6C:83:66:96:D1`
  - SHA-1 `22:B4:96:07:FC:F4:E1:40:36:FF:B3:76:97:2D:F0:29:61:F7:CC:23`
- **Faça cópia de segurança da pasta `assinatura/`.** Sem ela, não dá para
  publicar atualizações que instalem por cima.
- Para o build usar a chave, copie `assinatura/key.properties` para
  `android/key.properties` (o caminho do arquivo é relativo:
  `../../../assinatura/aplicativo-all-release.jks`). Também é possível usar
  as variáveis `ALL_STORE_FILE`, `ALL_STORE_PASSWORD`, `ALL_KEY_ALIAS` e
  `ALL_KEY_PASSWORD`.

## Passo a passo de uma versão

1. Suba `version:` no `pubspec.yaml` (ex.: `2.1.0+3`; o número depois do
   `+` precisa sempre aumentar).
2. Rode os testes e gere os APKs assinados:
   ```bash
   flutter test
   flutter build apk --release
   flutter build apk --release --split-per-abi --target-platform android-arm64
   ```
3. No ramo `distribuicao`, crie a pasta `v2.1.0/` com:
   `All-2.1.0.apk`, `All-2.1.0-arm64.apk`, `NOTAS.md` e `SHA256SUMS.txt`
   (gerado com `sha256sum *.apk > SHA256SUMS.txt`). Faça commit e envie.
4. No `main`, crie e envie a tag: `git tag -a v2.1.0 -m "All 2.1.0"` e
   `git push origin v2.1.0`. O fluxo Release cria a página da versão.
