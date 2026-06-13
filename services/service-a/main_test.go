package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestEndpoints(t *testing.T) {
	if err := os.Setenv("VERSION", "test-1.2.3"); err != nil {
		t.Fatalf("failed to set VERSION: %v", err)
	}
	defer os.Unsetenv("VERSION")

	hostname, _ := os.Hostname()

	tests := []struct {
		name       string
		path       string
		wantStatus int
		wantFields map[string]string
	}{
		{
			name:       "healthz",
			path:       "/healthz",
			wantStatus: http.StatusOK,
			wantFields: map[string]string{"status": "ok"},
		},
		{
			name:       "readyz",
			path:       "/readyz",
			wantStatus: http.StatusOK,
			wantFields: map[string]string{"status": "ready"},
		},
		{
			name:       "hello",
			path:       "/api/hello",
			wantStatus: http.StatusOK,
			wantFields: map[string]string{
				"service":  "service-a",
				"message":  "hello from service-a",
				"version":  "test-1.2.3",
				"hostname": hostname,
			},
		},
	}

	mux := newMux()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, tt.path, nil)
			rec := httptest.NewRecorder()

			mux.ServeHTTP(rec, req)

			if rec.Code != tt.wantStatus {
				t.Fatalf("status = %d, want %d", rec.Code, tt.wantStatus)
			}

			if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
				t.Errorf("Content-Type = %q, want application/json", ct)
			}

			var body map[string]string
			if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
				t.Fatalf("failed to decode JSON body: %v (body=%q)", err, rec.Body.String())
			}

			for k, want := range tt.wantFields {
				if got := body[k]; got != want {
					t.Errorf("field %q = %q, want %q", k, got, want)
				}
			}
		})
	}
}

func TestVersionDefault(t *testing.T) {
	os.Unsetenv("VERSION")
	if got := version(); got != "dev" {
		t.Errorf("version() = %q, want %q", got, "dev")
	}
}
