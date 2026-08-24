package main

import (
	"log"
	"net/http"
	"os"
	"time"
)

// newMux arma las rutas de la aplicación. Mantener el routing separado
// del ListenAndServe permite testear todo el servidor con httptest.
// Paridad exacta con el WebapiApplication.java original: texto plano.
func newMux(now func() time.Time) *http.ServeMux {
	mux := http.NewServeMux()

	// {$} coincide SOLO con el final de la URL: "GET /{$}" es el
	// exact-match de la raíz (como el @GetMapping("/") de Spring).
	// Sin esto, "GET /" sería prefix-match y "/noexiste" devolvería 200.
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		writeText(w, http.StatusOK, "Hello CI/CD World!")
	})

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeText(w, http.StatusOK, "Server Healthy!")
	})

	mux.HandleFunc("GET /date", func(w http.ResponseWriter, r *http.Request) {
		writeText(w, http.StatusOK, "Current Server Date: "+now().Format("2006-01-02"))
	})

	return mux
}

// writeText escribe una respuesta de texto plano con el status dado.
func writeText(w http.ResponseWriter, status int, body string) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(status)
	if _, err := w.Write([]byte(body)); err != nil {
		log.Printf("escribiendo respuesta: %v", err)
	}
}

func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}

	log.Printf("webapi escuchando en %s", addr)
	if err := http.ListenAndServe(addr, newMux(time.Now)); err != nil {
		log.Fatalf("el servidor terminó: %v", err)
	}
}
