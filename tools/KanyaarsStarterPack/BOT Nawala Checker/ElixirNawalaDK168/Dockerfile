ARG ELIXIR_VERSION=1.17.3
ARG OTP_VERSION=25.3.2.14
ARG DEBIAN_VERSION=bookworm-20240904-slim
ARG RUNNER_DEBIAN_VERSION=bookworm-20240904-slim

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION} AS builder

ENV MIX_ENV=prod
ENV LANG=C.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential git curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV ERL_INETRC=/etc/inetrc
RUN echo "{inet6, false}." > /etc/inetrc

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
COPY deps deps

RUN mix deps.compile

COPY lib lib
COPY priv priv
COPY assets assets

RUN mix phx.digest
RUN mix release

FROM debian:${RUNNER_DEBIAN_VERSION} AS runner

ENV MIX_ENV=prod
ENV LANG=C.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends openssl libstdc++6 libncurses5 ca-certificates tzdata && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN useradd --system --create-home --home-dir /app --shell /bin/bash app

COPY --from=builder --chown=app:app /app/_build/prod/rel/elixir_nawala_dk168 ./
COPY --chown=app:app docker/entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

USER app

EXPOSE 4000

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["start"]
