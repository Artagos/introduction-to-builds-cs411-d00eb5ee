# ---- Build stage ----
FROM golang:1.24 AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# ---- Final stage ----
FROM gcr.io/distroless/static-debian12

WORKDIR /app
COPY --from=builder /app/main .

ENTRYPOINT ["/app/main"]