package jobs

import (
	"context"
	"log/slog"
	"sync"
	"time"
)

// Scheduler runs the periodic hygiene passes. Each task keeps its own ticker
// so a slow one never delays the others, and each runs on the caller's
// goroutine rather than through the pool so a long sweep cannot starve
// interactive work like thumbnail generation.
type Scheduler struct {
	log     *slog.Logger
	cancel  context.CancelFunc
	ctx     context.Context
	wg      sync.WaitGroup
	started bool
	tasks   []task
}

type task struct {
	name    string
	every   time.Duration
	initial time.Duration
	run     func(ctx context.Context) error
}

// NewScheduler returns a scheduler that has not started yet.
func NewScheduler(log *slog.Logger) *Scheduler {
	if log == nil {
		log = slog.Default()
	}
	ctx, cancel := context.WithCancel(context.Background())
	return &Scheduler{log: log, ctx: ctx, cancel: cancel}
}

// Every registers a periodic task. initialDelay staggers startup so a restart
// does not run every sweep at once.
func (s *Scheduler) Every(name string, interval, initialDelay time.Duration, run func(ctx context.Context) error) {
	s.tasks = append(s.tasks, task{name: name, every: interval, initial: initialDelay, run: run})
}

// Start begins every registered task.
func (s *Scheduler) Start() {
	if s.started {
		return
	}
	s.started = true
	for _, t := range s.tasks {
		s.wg.Add(1)
		go s.loop(t)
	}
}

func (s *Scheduler) loop(t task) {
	defer s.wg.Done()
	if t.initial > 0 {
		select {
		case <-time.After(t.initial):
		case <-s.ctx.Done():
			return
		}
	}
	ticker := time.NewTicker(t.every)
	defer ticker.Stop()
	for {
		s.runOnce(t)
		select {
		case <-ticker.C:
		case <-s.ctx.Done():
			return
		}
	}
}

func (s *Scheduler) runOnce(t task) {
	defer func() {
		if r := recover(); r != nil {
			s.log.Error("scheduled task panicked", "task", t.name, "panic", r)
		}
	}()
	start := time.Now()
	if err := t.run(s.ctx); err != nil {
		if s.ctx.Err() != nil {
			return
		}
		s.log.Warn("scheduled task failed", "task", t.name, "error", err)
		return
	}
	s.log.Debug("scheduled task done", "task", t.name, "duration_ms", time.Since(start).Milliseconds())
}

// Stop cancels every task and waits for them to return.
func (s *Scheduler) Stop(ctx context.Context) error {
	s.cancel()
	done := make(chan struct{})
	go func() {
		s.wg.Wait()
		close(done)
	}()
	select {
	case <-done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}
