# LeggyMq

## **Requisitos:**

- Docker
- Elixir 1.18
- Erlang/OTP 27

## Configurando

Comece executando um docker compose para subir o serviço do RabbitMQ localmente:

```bash
docker compose up -d
```

Baixe as dependências:

```bash
mix deps.get
```

## Testando

Execute o iex localmente:

```bash
iex -S mix
```

Inicie a aplicação demo `demo_repo.ex`. Essa aplicação representa o lado do usuário e está usando nossa lib. As configs de conexão com o RabbitMQ poderão ser alteradas nesse arquivo.

```
iex> DemoRepo.start_link
```

O schema demo está definido em `email_schema_demo.ex` e pode ser alterado a vontade. Ele está definindo a exchange, queue e alguns campos arbitrários.

Vamos criar nossa exchange, queue e fazer o bind entre elas, com esse comando:

```elixir
iex> DemoRepo.prepare(EmailSchema)
```

Agora, vamos fazer o cast de um mapa para nosso schema demo:

```elixir
iex> params = %{user: "r2d2", ttl: 2, valid?: true, requested_at: DateTime.utc_now()}
iex> {:ok, msg} = DemoRepo.cast(EmailSchema, params)
```

Agora podemos publicar essa mensagem que foi feito o cast:

```
iex> DemoRepo.publish(msg)
```

Por último, podemos recuperar a mensagem que acabou de ser publicada:

```elixir
iex> DemoRepo.get(EmailSchema)
```
