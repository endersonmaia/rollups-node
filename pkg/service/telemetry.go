// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

package service

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

const telemetryShutdownTimeout = 5 * time.Second

type telemetryService struct {
	HTTPServiceTemplate
	supervisor Supervisor
	serveMux   *http.ServeMux
}

// createDefaultTelemetry serves /readyz and /livez, and also /metrics when
// metrics is not nil.
func createDefaultTelemetry(supervisor Supervisor, addr string, metrics prometheus.Gatherer) SupervisedService {
	s := &telemetryService{supervisor: supervisor}

	s.serveMux = http.NewServeMux()
	s.serveMux.Handle("/readyz", http.HandlerFunc(s.ReadyHandler))
	s.serveMux.Handle("/livez", http.HandlerFunc(s.AliveHandler))
	if metrics != nil {
		s.serveMux.Handle("/metrics", promhttp.HandlerFor(metrics, promhttp.HandlerOpts{}))
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set(requestIDHeader, "telemetry")
		s.serveMux.ServeHTTP(w, r)
	})

	cfg := &HTTPServiceConfigs{
		BaseConfigs: BaseConfigs{
			Name:   supervisor.String() + "/telemetry",
			Logger: supervisor.Logger(),
		},
		HTTPServerOptions: DefaultTelemetryOptions(),
		Address:           addr,
		ShutdownTimeout:   telemetryShutdownTimeout,
	}
	InitHTTPServiceTemplate(&s.HTTPServiceTemplate, cfg, handler)

	s.Logger.Info("Telemetry", "address", addr)

	return s
}

// ReadyHandler reports the names of services failing readiness.
func (s *telemetryService) ReadyHandler(w http.ResponseWriter, _ *http.Request) {
	if names := s.supervisor.NotReady(); len(names) > 0 {
		http.Error(w, s.Name+": ready check failed: "+strings.Join(names, ", "),
			http.StatusServiceUnavailable)
	} else {
		fmt.Fprintf(w, "%s: ready\n", s.Name)
	}
}

// HTTP handler for `/s.Name/livez` that exposes the value of Alive()
func (s *telemetryService) AliveHandler(w http.ResponseWriter, _ *http.Request) {
	if !s.supervisor.Alive() {
		http.Error(w, s.Name+": alive check failed",
			http.StatusInternalServerError)
	} else {
		fmt.Fprintf(w, "%s: alive\n", s.Name)
	}
}
