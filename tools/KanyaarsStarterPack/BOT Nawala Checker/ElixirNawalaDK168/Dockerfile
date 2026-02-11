ARG ELIXIR_VERSION=1.17.3
ARG OTP_VERSION=27.0
ARG DEBIAN_VERSION=bookworm

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION} AS builder

ENV MIX_ENV=prod
ENV LANG=C.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential git curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config

RUN mix deps.get --only ${MIX_ENV}
RUN mix deps.compile

COPY lib lib
COPY priv priv
COPY assets assets

RUN mix assets.deploy
RUN mix release

FROM debian:${DEBIAN_VERSION}-slim AS runner

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
