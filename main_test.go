package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// TestRutas cubre el comportamiento observable del servidor: status
// codes y payloads de cada ruta, incluyendo method no permitido y 404.
func TestRutas(t *testing.T) {
	ts := httptest.NewServer(newMux())
	t.Cleanup(ts.Close)

	tests := []struct {
		name       string
		method     string
		path       string
		wantStatus int
		wantBody   map[string]string
	}{
		{
			name:       "hello devuelve mensaje",
			method:     http.MethodGet,
			path:       "/hello",
			wantStatus: http.StatusOK,
			wantBody:   map[string]string{"message": "Hola desde la webapi en Go"},
		},
		{
			name:       "health reporta ok",
			method:     http.MethodGet,
			path:       "/health",
			wantStatus: http.StatusOK,
			wantBody:   map[string]string{"status": "ok"},
		},
		{
			name:       "método no permitido en hello",
			method:     http.MethodPost,
			path:       "/hello",
			wantStatus: http.StatusMethodNotAllowed,
		},
		{
			name:       "ruta inexistente",
			method:     http.MethodGet,
			path:       "/noexiste",
			wantStatus: http.StatusNotFound,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req, err := http.NewRequest(tt.method, ts.URL+tt.path, nil)
			if err != nil {
				t.Fatalf("creando request: %v", err)
			}

			res, err := http.DefaultClient.Do(req)
			if err != nil {
				t.Fatalf("ejecutando request: %v", err)
			}
			defer res.Body.Close()

			if res.StatusCode != tt.wantStatus {
				t.Errorf("status = %d, quería %d", res.StatusCode, tt.wantStatus)
			}

			if tt.wantBody == nil {
				return
			}

			var got map[string]string
			if err := json.NewDecoder(res.Body).Decode(&got); err != nil {
				t.Fatalf("decodificando respuesta: %v", err)
			}
			for k, want := range tt.wantBody {
				if got[k] != want {
					t.Errorf("%s = %q, quería %q", k, got[k], want)
				}
			}
		})
	}
}
