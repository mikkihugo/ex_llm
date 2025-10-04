# syntax=docker/dockerfile:1.6

ARG ELIXIR_VERSION=1.17.3
ARG OTP_VERSION=27.1.3
ARG BASE_VARIANT=ubuntu-noble-20250925
ARG GLEAM_VERSION=1.5.1

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-${BASE_VARIANT} AS build

ENV MIX_ENV=prod \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    openssl \
    libncurses5-dev \
    libssl-dev \
    bash \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force \
  && mix local.rebar --force

RUN curl -L "https://github.com/gleam-lang/gleam/releases/download/v${GLEAM_VERSION}/gleam-v${GLEAM_VERSION}-linux-x86_64.tar.gz" \
  | tar -xz -C /usr/local/bin

COPY mix.exs mix.lock ./
COPY gleam.toml ./
COPY config ./config
COPY lib ./lib
COPY gleam ./gleam
COPY rel ./rel

RUN mix deps.get --only prod
RUN mix gleam.deps.get
RUN mix compile
RUN mix release seed_agent

FROM debian:bookworm-slim AS runtime

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MIX_ENV=prod \
    RELEASE_NAME=seed_agent

RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl libstdc++6 libtinfo6 ca-certificates curl \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --system --shell /bin/false app

WORKDIR /app

COPY --from=build /app/_build/prod/rel/seed_agent ./

RUN mkdir -p /data/code \
  && chown -R app:app /data /app

VOLUME ["/data/code"]

ENV PORT=8080 \
    RELEASE_COOKIE=change-me \
    ERL_AFLAGS="-proto_dist inet6_tcp"

EXPOSE 8080

USER app

ENTRYPOINT ["/app/bin/seed_agent"]
CMD ["start"]
