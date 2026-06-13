# syntax=docker/dockerfile:1

# ---- Build stage ----
FROM golang:1.22-alpine AS build

ARG VERSION=dev

WORKDIR /src

# Copy module files first to leverage layer caching. No external deps,
# so there is nothing to download, but this keeps the pattern consistent.
COPY go.mod ./
COPY . .

# Build a static binary (CGO disabled), stamping the version via ldflags
# into the package-level fallback is unnecessary since version is read from
# env at runtime; we still set VERSION as a build arg for traceability and
# pass it through for image labelling / reproducibility.
RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/service-a .

# ---- Final stage ----
FROM gcr.io/distroless/static-debian12:nonroot

ARG VERSION=dev
ENV VERSION=${VERSION}

WORKDIR /

COPY --from=build /out/service-a /service-a

USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/service-a"]
