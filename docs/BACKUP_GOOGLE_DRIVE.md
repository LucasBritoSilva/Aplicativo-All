# Backup no Google Drive (opcional, desligado nesta versão)

O app tem o código de backup manual: ele grava um arquivo JSON na pasta
privada do app no seu Google Drive (`appDataFolder`) e só restaura depois
de confirmar. O cofre nunca entra no backup.

Para funcionar, o Google exige um "cliente OAuth do tipo Android" criado no
Google Cloud, ligado ao nome do pacote e à impressão digital da chave que
assina o APK. Isso depende de uma conta Google do proprietário e por isso
**não foi feito automaticamente**. Sem ele, os botões de backup ficam
desativados e o resto do app funciona normalmente.

## Como ligar (para quem compila o app)

1. Em <https://console.cloud.google.com>, crie um projeto e ative a
   **Google Drive API** (APIs e serviços → Biblioteca).
2. Configure a **Tela de permissão OAuth** (público Externo) e adicione o seu
   e-mail como usuário de teste.
3. Crie um **ID do cliente OAuth** do tipo **Android**:
   - Nome do pacote: `io.github.lucasbritosilva.aplicativoall`
   - SHA-1 do certificado de produção:
     `22:B4:96:07:FC:F4:E1:40:36:FF:B3:76:97:2D:F0:29:61:F7:CC:23`
4. Copie o ID (termina em `.apps.googleusercontent.com`) para
   `assets/config/google_drive.json`, no campo `android_client_id`.
5. Gere e publique uma nova versão (ver [PUBLICACAO.md](PUBLICACAO.md)).

O ID do cliente Android não é segredo (ele só funciona para o APK assinado
com a sua chave), mas nenhum valor foi inventado neste repositório.
