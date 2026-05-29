# ---- Build stage ----
FROM golang:1.24 AS builder

WORKDIR /app

COPY main.go .

RUN CGO_ENABLED=0 GOOS=linux go build -o app main.go

# ---- Final stage ----
FROM gcr.io/distroless/static-debian12

WORKDIR /app
COPY --from=builder /app/app .

EXPOSE 4444

CMD ["/app/app"]