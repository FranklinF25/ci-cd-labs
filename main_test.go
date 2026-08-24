package main

import (
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// fechaFija elimina el no-determinismo de /date para poder assertear
// el payload exacto, igual que hace el test original de Spring.
var fechaFija = time.Date(2026, time.August, 23, 12, 0, 0, 0, time.UTC)

// TestRutas cubre el comportamiento observable del servidor: status,
// content-type y body de cada ruta, en paridad con WebapiApplicationTests.
func TestRutas(t *testing.T) {
	ts := httptest.NewServer(newMux(func() time.Time { return fechaFija }))
	t.Cleanup(ts.Close)

	tests := []struct {
		name       string
		method     string
		path       string
		wantStatus int
		wantType   string
		wantBody   string
	}{
		{
			name:       "raíz devuelve hello",
			method:     http.MethodGet,
			path:       "/",
			wantStatus: http.StatusOK,
			wantType:   "text/plain; charset=utf-8",
			wantBody:   "Hello CI/CD World!",
		},
		{
			name:       "health reporta healthy",
			method:     http.MethodGet,
			path:       "/health",
			wantStatus: http.StatusOK,
			wantType:   "text/plain; charset=utf-8",
			wantBody:   "Server Healthy!",
		},
		{
			name:       "date devuelve fecha del servidor",
			method:     http.MethodGet,
			path:       "/date",
			wantStatus: http.StatusOK,
			wantType:   "text/plain; charset=utf-8",
			wantBody:   "Current Server Date: 2026-08-23",
		},
		{
			name:       "método no permitido en health",
			method:     http.MethodPost,
			path:       "/health",
			wantStatus: http.StatusMethodNotAllowed,
			wantType:   "text/plain; charset=utf-8",
			wantBody:   "Method Not Allowed\n",
		},
		{
			name:       "ruta inexistente",
			method:     http.MethodGet,
			path:       "/noexiste",
			wantStatus: http.StatusNotFound,
			wantBody:   "404 page not found\n",
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

			if tt.wantType != "" {
				if got := res.Header.Get("Content-Type"); got != tt.wantType {
					t.Errorf("content-type = %q, quería %q", got, tt.wantType)
				}
			}

			body, err := io.ReadAll(res.Body)
			if err != nil {
				t.Fatalf("leyendo body: %v", err)
			}
			if string(body) != tt.wantBody {
				t.Errorf("body = %q, quería %q", string(body), tt.wantBody)
			}
		})
	}
}
