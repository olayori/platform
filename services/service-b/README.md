# service-b

A lightweight "time" API written in Go using only the standard library. Part of
the EKS GitOps platform.

## What it does

Exposes a small HTTP API that returns the current UTC time plus service metadata,
along with Kubernetes-style liveness and readiness probes. It supports graceful
shutdown on `SIGTERM`/`SIGINT` so it plays nicely with Kubernetes pod lifecycle.

## Endpoints

| Method | Path        | Description        | Response                                                                                          |
| ------ | ----------- | ------------------ | ------------------------------------------------------------------------------------------------- |
| GET    | `/healthz`  | Liveness probe     | `{"status":"ok"}`                                                                                 |
| GET    | `/readyz`   | Readiness probe    | `{"status":"ready"}`                                                                              |
| GET    | `/api/time` | Current time + info| `{"service":"service-b","utc":"<RFC3339>","unix":<int>,"version":"<VERSION>","hostname":"<host>"}` |

## Configuration

| Env var   | Default | Description                  |
| --------- | ------- | ---------------------------- |
| `PORT`    | `8080`  | TCP port to listen on        |
| `VERSION` | `dev`   | Reported in `/api/time`      |

## Run locally

```sh
go run .
# or with overrides:
PORT=9090 VERSION=1.2.3 go run .

curl localhost:8080/api/time
```

## Test

```sh
go test ./...
```

## Build Docker image

```sh
docker build --build-arg VERSION=1.2.3 -t service-b:1.2.3 .
docker run --rm -p 8080:8080 service-b:1.2.3
```

The image is a minimal multi-stage build producing a static, CGO-free binary on
top of `gcr.io/distroless/static-debian12:nonroot`, running as a non-root user.
