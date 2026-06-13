# Adowol Frontend

A minimal single-page static frontend for the Adowol Platform demo. No
framework, no build step — just HTML, vanilla JS, and CSS served by nginx.

On load it fetches two backend APIs through the ingress and renders the JSON
responses in two cards:

- `/api/hello` &rarr; service-a
- `/api/time` &rarr; service-b

A **Refresh** button re-runs both fetches. If a request fails, the affected
card shows an error message instead of crashing the page.

## Layout

```
services/frontend/
  src/index.html    # the page
  src/app.js        # fetch + render logic
  src/styles.css    # styling
  nginx.conf        # server block (listen 8080, /healthz, SPA fallback)
  Dockerfile        # nginxinc/nginx-unprivileged:1.27-alpine
  test/smoke.test.js
```

## Run locally

The page uses relative paths (`/api/...`), so the backends only resolve when
served behind the platform ingress. To preview the UI itself locally:

```bash
npx serve src
# or
python3 -m http.server 8080 --directory src
```

The two cards will show fetch errors until the `/api/*` routes exist — that is
expected and exercises the error-handling path.

## Test

Uses Node's built-in test runner and assertions — no `npm install` needed:

```bash
npm test          # node --test test/
npm run lint      # node test/smoke.test.js
```

The smoke test asserts that `index.html` and `app.js` contain the expected
elements and endpoint references, and that `nginx.conf` is wired correctly.

## Build the container

```bash
docker build -t adowol-frontend:dev .
docker run --rm -p 8080:8080 adowol-frontend:dev
```

## nginx port note

The image is based on `nginxinc/nginx-unprivileged`, which runs as a non-root
user. nginx therefore listens on **8080** (not the privileged port 80), writes
its pid to `/tmp/nginx.pid`, and keeps temp paths under `/tmp`. This lets the
pod run with a restricted, non-root security context in Kubernetes.
`GET /healthz` returns `200 ok` for liveness/readiness probes.
