package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

const serviceName = "service-a"

// version is resolved from the VERSION env var (default "dev").
func version() string {
	if v := os.Getenv("VERSION"); v != "" {
		return v
	}
	return "dev"
}

// writeJSON writes v as a JSON response with the given status code.
func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf(`{"level":"error","msg":"failed to encode response","error":%q}`, err.Error())
	}
}

func healthzHandler(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func readyzHandler(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
	hostname, err := os.Hostname()
	if err != nil {
		hostname = "unknown"
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"service":  serviceName,
		"message":  "hello from " + serviceName,
		"version":  version(),
		"hostname": hostname,
	})
}

// accessLog wraps a handler and emits a simple structured access log line.
func accessLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(sw, r)
		log.Printf(`{"level":"info","method":%q,"path":%q,"status":%d,"duration_ms":%d,"remote":%q}`,
			r.Method, r.URL.Path, sw.status, time.Since(start).Milliseconds(), r.RemoteAddr)
	})
}

// statusWriter captures the response status code for access logging.
type statusWriter struct {
	http.ResponseWriter
	status int
}

func (s *statusWriter) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

// newMux builds the HTTP router with all service routes registered.
func newMux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", healthzHandler)
	mux.HandleFunc("/readyz", readyzHandler)
	mux.HandleFunc("/api/hello", helloHandler)
	return mux
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      accessLog(newMux()),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Run the server in a goroutine so it does not block shutdown handling.
	go func() {
		log.Printf(`{"level":"info","msg":"starting %s","port":%q,"version":%q}`, serviceName, port, version())
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf(`{"level":"fatal","msg":"server error","error":%q}`, err.Error())
		}
	}()

	// Wait for SIGTERM/SIGINT for graceful shutdown (important for k8s).
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, syscall.SIGINT)
	<-stop

	log.Printf(`{"level":"info","msg":"shutdown signal received, draining"}`)

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf(`{"level":"fatal","msg":"graceful shutdown failed","error":%q}`, err.Error())
	}
	log.Printf(`{"level":"info","msg":"stopped cleanly"}`)
}
