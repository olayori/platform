package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestEndpoints(t *testing.T) {
	router := newRouter()

	tests := []struct {
		name       string
		path       string
		wantStatus int
		wantFields map[string]string // exact string field assertions
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
			name:       "api time",
			path:       "/api/time",
			wantStatus: http.StatusOK,
			wantFields: map[string]string{"service": "service-b"},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, tc.path, nil)
			rec := httptest.NewRecorder()

			router.ServeHTTP(rec, req)

			if rec.Code != tc.wantStatus {
				t.Fatalf("status = %d, want %d", rec.Code, tc.wantStatus)
			}

			var body map[string]interface{}
			if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
				t.Fatalf("invalid JSON response: %v (body=%q)", err, rec.Body.String())
			}

			for k, want := range tc.wantFields {
				got, ok := body[k].(string)
				if !ok {
					t.Fatalf("field %q missing or not a string in %v", k, body)
				}
				if got != want {
					t.Errorf("field %q = %q, want %q", k, got, want)
				}
			}
		})
	}
}

func TestTimeUnixPositive(t *testing.T) {
	router := newRouter()

	req := httptest.NewRequest(http.MethodGet, "/api/time", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	var body map[string]interface{}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}

	// JSON numbers decode to float64.
	unix, ok := body["unix"].(float64)
	if !ok {
		t.Fatalf("unix field missing or not a number in %v", body)
	}
	if unix <= 0 {
		t.Errorf("unix = %v, want > 0", unix)
	}
}
