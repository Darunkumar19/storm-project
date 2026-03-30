# ── Stage 1: Build ──────────────────────────────────
FROM haskell:9.10 AS builder

WORKDIR /app
COPY . /app

# Build the project (--fast skips optimizations for faster compile)
RUN stack build --system-ghc --fast --jobs=1

# Copy the built binary to a known location
RUN cp "$(stack path --local-install-root --system-ghc)/bin/StormProject-exe" /app/server

# ── Stage 2: Runtime (tiny image) ───────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      libgmp10 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/server /app/server
COPY --from=builder /app/historical_storms.csv /app/historical_storms.csv

EXPOSE 3000

CMD ["/app/server"]