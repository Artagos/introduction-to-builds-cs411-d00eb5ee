# ---- Build stage ----
FROM golang:1.24 AS builder

WORKDIR /app

COPY main.go .

RUN CGO_ENABLED=0 GOOS=linux go build -o app main.go

# ---- Final stage ----
FROM alpine:3.21

WORKDIR /app
COPY --from=builder /app/app .

EXPOSE 4444

HEALTHCHECK --interval=10s --timeout=2s \
    CMD wget -qO- http://localhost:4444/ || exit 1

CMD ["/app/app"]