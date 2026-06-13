# service-a

A lightweight "greeter" HTTP microservice written in Go using only the standard
library. Part of the EKS GitOps platform.

## What it does

Exposes a tiny JSON API plus Kubernetes liveness/readiness probes. It is
stateless, logs structured access lines to stdout, and shuts down gracefully on
`SIGTERM`/`SIGINT`.

## Endpoints

| Method | Path         | Status | Response                                                                                                       |
| ------ | ------------ | ------ | -------------------------------------------------------------------------------------------------------------- |
| GET    | `/healthz`   | 200    | `{"status":"ok"}` (liveness)                                                                                    |
| GET    | `/readyz`    | 200    | `{"status":"ready"}` (readiness)                                                                                |
| GET    | `/api/hello` | 200    | `{"service":"service-a","message":"hello from service-a","version":"<VERSION>","hostname":"<os.Hostname()>"}`   |

## Configuration

| Env var   | Default | Description                          |
| --------- | ------- | ------------------------------------ |
| `PORT`    | `8080`  | TCP port the server listens on.      |
| `VERSION` | `dev`   | Version string returned by `/api/hello`. |

## Run locally

```sh
go run .
# or with overrides:
PORT=9090 VERSION=1.0.0 go run .

curl localhost:8080/healthz
curl localhost:8080/readyz
curl localhost:8080/api/hello
```

## Test

```sh
go test ./...
```

## Build the Docker image

Multi-stage build producing a minimal distroless image that runs as `nonroot`.

```sh
docker build --build-arg VERSION=1.0.0 -t service-a:1.0.0 .
docker run --rm -p 8080:8080 service-a:1.0.0
```
