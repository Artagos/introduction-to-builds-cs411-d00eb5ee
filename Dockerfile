FROM golang:1.24

WORKDIR /app

COPY main.go .

RUN go build -o app main.go

EXPOSE 4444

CMD ["./app"]
