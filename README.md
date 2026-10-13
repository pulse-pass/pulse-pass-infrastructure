# pulse-pass-infrastructure

Infraestrutura compartilhada do PulsePass no ambiente local: a rede Docker `pulse-pass` e os componentes usados por todos os serviços. Por enquanto só o Keycloak; Redis, Kafka, Mailpit e MinIO entram quando alguma tarefa precisar deles.

## Como usar

Só é preciso ter o Docker instalado.

```
./infrastructure-start.sh   # cria a rede pulse-pass, copia .env.example para .env (se faltar) e sobe tudo
./infrastructure-stop.sh    # derruba os contêineres e remove os volumes
```

O script de subida espera o healthcheck dos contêineres antes de terminar. A rede `pulse-pass` nunca é removida, porque os composes dos serviços também a usam (o script de parada a cria se ela não existir, pois o compose a declara como externa).

## Keycloak

Versão 26.0.7 em modo `start-dev`, com banco embutido, importando o realm de `keycloak/pulse-pass-realm.json`. O realm só é importado quando o contêiner é criado; depois de editar o JSON, rode `./infrastructure-stop.sh` antes de subir de novo, senão a alteração não é aplicada.

| Item | Valor |
| --- | --- |
| Contêiner | `pulse-pass-keycloak` |
| Console admin | http://localhost:8180 (usuário e senha em `.env`, padrão `admin` / `admin`) |
| Endereço interno | `http://pulse-pass-keycloak:8080`, para os serviços na rede `pulse-pass` |
| Realm | `pulse-pass` |

O realm `pulse-pass` tem login por usuário (o CPF), e-mail repetido permitido, cadastro pela tela desativado e política de senha com no mínimo 8 caracteres. Os papéis `buyer`, `organizer` e `admin` existem, mas não são atribuídos por padrão. O atributo `person_key` (editável só por administradores) vai para o token na claim de mesmo nome.

O client `onboarding-service` é confidencial, usa client credentials e password grant, e seu service account pode criar e consultar usuários (`manage-users`, `view-users` e `view-realm`, este último para consultar os papéis do realm). O secret de desenvolvimento está versionado no realm: `onboarding-service-development-secret`. Por enquanto o mapper da claim `person_key` existe só nesse client.

## Portas

| Porta | Uso |
| --- | --- |
| 8180 | Keycloak (configurável por `KEYCLOAK_PORT` no `.env`), publicada só em 127.0.0.1 |

## Pipeline

O workflow `CI` (`.github/workflows/pull-request.yml`) roda em pull requests para a `main`: valida o compose e o JSON do realm, sobe a infraestrutura, confere que o realm responde e, com um token do service account do `onboarding-service`, confere que ele consulta o papel `organizer` e que `buyer`, `organizer` e `admin` existem.
