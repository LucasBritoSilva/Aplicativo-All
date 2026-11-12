# Segurança do cofre

## Como o conteúdo é protegido

- Cada registro (título, categoria e informação) é cifrado com
  **AES-256-GCM** antes de ir para o banco. No banco só existe o texto
  cifrado (`vault_entries.payload`).
- A chave é criada e guardada no **Android Keystore** (em hardware seguro,
  quando o aparelho tem). Ela não pode ser exportada nem lida pelo app.
- A chave só pode ser usada por **10 minutos depois de o usuário se
  autenticar** com biometria forte (digital/rosto classe 3) ou com o
  bloqueio de tela (PIN, padrão ou senha). Por isso o cofre exige que o
  celular tenha um bloqueio de tela.
- O cofre **tranca sozinho** quando o app sai da tela e quando você fecha a
  tela do cofre. Ele também pede a autenticação de novo depois do prazo.
- Enquanto o cofre está aberto, a tela fica protegida (`FLAG_SECURE`): não
  sai em capturas, gravações nem na prévia da lista de apps recentes.
- Copiar uma informação marca o conteúdo como sensível, para o Android não
  mostrar a prévia do que foi copiado.
- Nenhum conteúdo do cofre é escrito em log.

## Backup e recuperação

- O cofre **não entra** no backup do Google Drive e o backup automático do
  Android está desligado. Isso é proposital: a chave fica presa a este
  aparelho.
- **Consequência:** se o app for desinstalado, os dados do app forem
  apagados, o celular for formatado ou trocado, **o conteúdo do cofre é
  perdido**. Guarde em outro lugar seguro o que não pode ser perdido.
- Se o bloqueio de tela do celular for removido, o Android pode invalidar a
  chave. O app avisa e oferece **Apagar o cofre** para recomeçar.

## O que o cofre não faz

- Não protege contra quem já conhece o seu bloqueio de tela ou tem a sua
  digital cadastrada no aparelho.
- Não protege um celular com acesso root/modificado.
- Não exporta o conteúdo. Não existe "esqueci a senha": a proteção é a do
  próprio celular.
