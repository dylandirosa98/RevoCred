FROM golang:1.26.10-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/revocred-api ./cmd/api

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/revocred-api /revocred-api
EXPOSE 8080
USER nonroot:nonroot
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD ["/revocred-api", "--healthcheck"]
ENTRYPOINT ["/revocred-api"]
