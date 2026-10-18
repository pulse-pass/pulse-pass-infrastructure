# pulse-pass-infrastructure

Infraestrutura compartilhada do PulsePass no ambiente local: a rede Docker `pulse-pass` e os componentes usados por todos os serviços. Hoje são Keycloak, MySQL, Redis e Kafka; Mailpit, MinIO e Kafka UI entram quando alguma tarefa precisar deles. Os serviços usam esta infraestrutura só no modo `development`; no modo `test` cada serviço sobe as próprias dependências.

## Como usar

Só é preciso ter o Docker instalado.

```
./infrastructure-start.sh   # cria a rede pulse-pass, copia .env.example para .env (se faltar), derruba o ambiente anterior e sobe tudo
./infrastructure-stop.sh    # derruba os contêineres e remove os volumes
```

O script de subida chama o de parada antes de subir, então todo start começa do zero: os contêineres e os volumes anteriores são removidos e o MySQL volta vazio. Por isso os serviços em modo `development` precisam rodar o `service-start.sh development` de novo para recriar o schema e o usuário. O script de subida espera o healthcheck dos contêineres antes de terminar. A rede `pulse-pass` nunca é removida, porque os composes dos serviços também a usam (o script de parada a cria se ela não existir, pois o compose a declara como externa).

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

## MySQL

Versão 8.0, contêiner `pulse-pass-mysql`. Sobe vazio, só com o usuário `root` (senha em `MYSQL_ROOT_PASSWORD` no `.env`, padrão `root`). Cada serviço cria o próprio schema e usuário pelo seu `database.sql`, um banco por serviço. Endereço interno: `pulse-pass-mysql:3306`.

## Redis

Versão 7.4, contêiner `pulse-pass-redis`. Endereço interno: `pulse-pass-redis:6379`.

## Kafka

Versão 3.9.1 em modo KRaft com um nó (broker e controller juntos), contêiner `pulse-pass-kafka`. Tem dois listeners: o interno, `pulse-pass-kafka:9092`, para os contêineres na rede `pulse-pass`, e o externo, `localhost:9094`, para quem roda no host. A porta 9094 é o padrão e pode ser trocada por `KAFKA_PORT` no `.env`.

## Portas

| Porta | Uso |
| --- | --- |
| 8180 | Keycloak (configurável por `KEYCLOAK_PORT` no `.env`), publicada só em 127.0.0.1 |
| 3306 | MySQL (`MYSQL_PORT`), publicada só em 127.0.0.1 |
| 6379 | Redis (`REDIS_PORT`), publicada só em 127.0.0.1 |
| 9094 | Kafka, listener externo (`KAFKA_PORT`), publicada só em 127.0.0.1 |

Essas portas não podem ser usadas pelos serviços no modo `test`.

## Pipeline

O workflow `CI` (`.github/workflows/pull-request.yml`) roda em pull requests para a `main`: valida o compose e o JSON do realm, sobe a infraestrutura, confere que o realm responde e, com um token do service account do `onboarding-service`, confere que ele consulta o papel `organizer` e que `buyer`, `organizer` e `admin` existem. Em seguida confere o MySQL (`SELECT 1`), o Redis (`PONG`) e o Kafka (cria um tópico e o lista pelo listener interno, pelo externo e a partir de outro contêiner da rede `pulse-pass`).
