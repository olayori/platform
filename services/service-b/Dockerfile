# syntax=docker/dockerfile:1

# --- Build stage ---
FROM golang:1.22-alpine AS build

ARG VERSION=dev

WORKDIR /src

# Copy go.mod first for layer caching (no external deps, so no go.sum needed).
COPY go.mod ./
RUN go mod download

COPY . .

# Static, CGO-free binary.
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w" \
    -trimpath \
    -o /out/service-b .

# --- Final stage ---
FROM gcr.io/distroless/static-debian12:nonroot

ARG VERSION=dev
ENV VERSION=${VERSION}

COPY --from=build /out/service-b /service-b

EXPOSE 8080

USER nonroot:nonroot

ENTRYPOINT ["/service-b"]
