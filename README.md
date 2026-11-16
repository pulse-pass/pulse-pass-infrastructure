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

O realm `pulse-pass` tem login por usuário (o CPF), e-mail repetido permitido, cadastro pela tela desativado e política de senha com no mínimo 8 caracteres. Os papéis `buyer`, `organizer` e `admin` existem, mas não são atribuídos por padrão, exceto ao administrador de desenvolvimento (papel `admin`). O atributo `person_key` (editável só por administradores) vai para o token na claim de mesmo nome.

O client `onboarding-service` é confidencial, usa client credentials e password grant, e seu service account pode criar e consultar usuários (`manage-users`, `view-users` e `view-realm`, este último para consultar os papéis do realm). O secret vem da variável `ONBOARDING_SERVICE_CLIENT_SECRET` do `.env` (valor de desenvolvimento no `.env.example`: `onboarding-service-development-secret`). Por enquanto os mappers das claims `person_key` e `legal_person_key` existem só nesse client. O atributo `legal_person_key` tem a mesma regra do `person_key` (visão e edição só por administradores).

O realm também traz um administrador de desenvolvimento, usado para entrar no backoffice: usuário (CPF) `52998224725` e senha em `BACKOFFICE_ADMIN_PASSWORD` no `.env` (padrão `pulsepass-admin`), com o papel `admin`, o `person_key` fixo `00000000-0000-4000-8000-000000000001` e sem `legal_person_key`. As claims do token incluem o nome, o `person_key`, o `legal_person_key` (quando o usuário tem) e `realm_access.roles`.

Os tokens são assinados com um par RSA fixo (RS256), para que o gateway do backoffice valide a assinatura com a chave pública da sua configuração. A chave privada e o certificado vêm de `KEYCLOAK_RSA_PRIVATE_KEY` e `KEYCLOAK_RSA_CERTIFICATE` no `.env` (base64 do PEM sem as linhas BEGIN/END). O par do `.env.example` existe só para desenvolvimento; a chave pública correspondente está no `.env.example` do `backoffice-gateway`. O issuer dos tokens emitidos no login, que passa sempre pelo `onboarding-service`, é `http://pulse-pass-keycloak:8080/realms/pulse-pass`, o endereço pelo qual o serviço chama o Keycloak; um token obtido direto em `localhost:8180` tem outro issuer e é recusado pelo gateway.

Cada refresh token vale para uma única renovação: o realm liga `revokeRefreshToken` com `refreshTokenMaxReuse` em 0, então a renovação devolve um refresh token novo e o anterior deixa de valer. Reapresentar um token já usado é recusado com `invalid_grant` (o `onboarding-service` responde 401) e, além disso, o Keycloak encerra a sessão: o token novo emitido naquela renovação também passa a ser recusado com `invalid_grant`, e o usuário precisa entrar de novo. Como o realm só é importado quando o contêiner é criado, a mudança vale somente com o ambiente recriado (`./infrastructure-stop.sh` e `./infrastructure-start.sh`).

O access token vale 2 minutos (`accessTokenLifespan` em 120). Quando uma organização é removida, o `onboarding-service` desativa os usuários dos colaboradores e encerra as sessões deles, e o login e o refresh passam a ser recusados. O access token que já tinha sido emitido continua válido até expirar, e o prazo curto limita esse acesso residual. A mudança também só vale com o ambiente recriado.

O realm não guarda segredos: o arquivo usa `${VARIÁVEL}`, que o Keycloak substitui no import pelas variáveis que o compose repassa do `.env`. Um `.env` criado antes dessas variáveis precisa ser apagado para ser recriado a partir do `.env.example`.

Donos de organização cadastrados antes dessa mudança não têm o atributo `legal_person_key`; é preciso recriar o ambiente (`./infrastructure-stop.sh` e `./infrastructure-start.sh`) e cadastrá-los de novo.

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

O workflow `CI` (`.github/workflows/pull-request.yml`) roda em pull requests para a `main`: valida o compose e o JSON do realm, sobe a infraestrutura, confere que o realm responde e, com um token do service account do `onboarding-service`, confere que ele consulta o papel `organizer` e que `buyer`, `organizer` e `admin` existem. Depois confere a rotação do refresh token: o token antigo é recusado com `invalid_grant` depois de uma renovação e a sessão é encerrada no reuso. Em seguida confere o MySQL (`SELECT 1`), o Redis (`PONG`) e o Kafka (cria um tópico e o lista pelo listener interno, pelo externo e a partir de outro contêiner da rede `pulse-pass`).
