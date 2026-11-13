# Como o BrutAll é compilado e publicado

O BrutAll é distribuído como versão final, pela página de Releases do
GitHub. O app não tem verificação nem mecanismo de atualização.

## Automação

- **CI** (`.github/workflows/ci.yml`): a cada envio para `main`, roda
  análise, testes e gera um APK de teste (assinado com chave de debug
  descartável), disponível em Actions → artefato `all-apk-de-teste`.
- **Release** (`.github/workflows/release.yml`): ao enviar uma tag `vX.Y.Z`,
  pega os arquivos da pasta `vX.Y.Z/` do ramo `distribuicao`, confere o
  SHA-256 e cria a Release pública.
- O APK de produção é assinado **no computador do proprietário**. A chave
  nunca vai para o GitHub (`*.jks`, `*.keystore` e `key.properties` estão
  no `.gitignore`).

## Chave de assinatura

- Arquivo: `aplicativo-all-release.jks` (PKCS12, RSA 4096, válida até 2126),
  numa pasta `assinatura/` fora do repositório, com o `key.properties`
  (senha) e um LEIA-ME.
- Impressões digitais do certificado:
  - SHA-256 `DA:04:16:40:6D:56:29:46:FB:77:BB:61:11:8C:2A:AD:E7:94:0A:E5:3D:99:96:3F:6D:F8:D3:6C:83:66:96:D1`
  - SHA-1 `22:B4:96:07:FC:F4:E1:40:36:FF:B3:76:97:2D:F0:29:61:F7:CC:23`
- Para o build usar a chave, copie `assinatura/key.properties` para
  `android/key.properties` (o caminho do arquivo é relativo:
  `../../../assinatura/aplicativo-all-release.jks`). Também é possível usar
  as variáveis `ALL_STORE_FILE`, `ALL_STORE_PASSWORD`, `ALL_KEY_ALIAS` e
  `ALL_KEY_PASSWORD`.

## Gerar o APK assinado

```bash
flutter test
flutter build apk --release
```

O arquivo sai em `build/app/outputs/flutter-apk/app-release.apk` e é
publicado com o nome `BrutAll.apk`, junto com `SHA256SUMS.txt`.
