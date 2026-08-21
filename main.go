package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

// helloResponse es el payload que sirve GET /hello.
type helloResponse struct {
	Message string `json:"message"`
}

// healthResponse es el payload que sirve GET /health.
type healthResponse struct {
	Status string `json:"status"`
}

// newMux arma las rutas de la aplicación. Mantener el routing separado
// del ListenAndServe permite testear todo el servidor con httptest.
func newMux() *http.ServeMux {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /hello", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, helloResponse{Message: "Hola desde la webapi en Go"})
	})

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, healthResponse{Status: "ok"})
	})

	return mux
}

// writeJSON serializa payload como respuesta JSON con el status dado.
func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("encoding respuesta: %v", err)
	}
}

func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}

	log.Printf("webapi escuchando en %s", addr)
	if err := http.ListenAndServe(addr, newMux()); err != nil {
		log.Fatalf("el servidor terminó: %v", err)
	}
}
