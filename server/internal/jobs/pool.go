// Package jobs is the in-process worker pool. One buffered queue, a fixed
// number of workers, and a small scheduler for the periodic hygiene passes.
// No external queue service at this scale.
package jobs

import (
	"context"
	"log/slog"
	"sync"
	"sync/atomic"
	"time"
)

// Kind names a job type, used for logging and metrics.
type Kind string

// Job kinds. One per thing that is actually submitted; a name is added here
// when the work that uses it lands, not before.
const (
	KindThumbnail  Kind = "thumbnail"
	KindVerify     Kind = "verify_checksum"
	KindMirror     Kind = "browse_mirror"
	KindTrashPurge Kind = "trash_purge"
)

// Job is one unit of background work.
type Job struct {
	Kind Kind
	Name string
	Run  func(ctx context.Context) error
}

// Pool runs jobs on a fixed number of workers.
type Pool struct {
	queue     chan Job
	workers   int
	log       *slog.Logger
	wg        sync.WaitGroup
	ctx       context.Context
	cancel    context.CancelFunc
	submitted atomic.Int64
	completed atomic.Int64
	failed    atomic.Int64
	dropped   atomic.Int64
	closing   atomic.Bool
}

// NewPool starts a pool with the configured worker count.
func NewPool(workers, queueDepth int, log *slog.Logger) *Pool {
	if workers <= 0 {
		workers = 2
	}
	if queueDepth <= 0 {
		queueDepth = 512
	}
	if log == nil {
		log = slog.Default()
	}
	ctx, cancel := context.WithCancel(context.Background())
	p := &Pool{
		queue:   make(chan Job, queueDepth),
		workers: workers,
		log:     log,
		ctx:     ctx,
		cancel:  cancel,
	}
	for i := 0; i < workers; i++ {
		p.wg.Add(1)
		go p.worker(i)
	}
	return p
}

func (p *Pool) worker(id int) {
	defer p.wg.Done()
	for job := range p.queue {
		p.runOne(id, job)
	}
}

func (p *Pool) runOne(worker int, job Job) {
	defer func() {
		if r := recover(); r != nil {
			p.failed.Add(1)
			p.log.Error("job panicked", "kind", string(job.Kind), "name", job.Name, "panic", r)
		}
	}()
	start := time.Now()
	if err := job.Run(p.ctx); err != nil {
		p.failed.Add(1)
		p.log.Warn("job failed", "kind", string(job.Kind), "name", job.Name, "error", err,
			"duration_ms", time.Since(start).Milliseconds(), "worker", worker)
		return
	}
	p.completed.Add(1)
	p.log.Debug("job done", "kind", string(job.Kind), "name", job.Name,
		"duration_ms", time.Since(start).Milliseconds(), "worker", worker)
}

// Submit queues a job. It never blocks: a full queue drops the job with a
// warning, since every job type here is either retried by a periodic pass or
// is a best-effort convenience.
func (p *Pool) Submit(job Job) bool {
	if p.closing.Load() {
		return false
	}
	select {
	case p.queue <- job:
		p.submitted.Add(1)
		return true
	default:
		p.dropped.Add(1)
		p.log.Warn("job queue full, job dropped", "kind", string(job.Kind), "name", job.Name)
		return false
	}
}

// Stats reports counters for /metrics.
func (p *Pool) Stats() (submitted, completed, failed, dropped, queued int64) {
	return p.submitted.Load(), p.completed.Load(), p.failed.Load(), p.dropped.Load(), int64(len(p.queue))
}

// Close stops accepting work, drains what is queued, and waits for workers.
func (p *Pool) Close(ctx context.Context) error {
	if !p.closing.CompareAndSwap(false, true) {
		return nil
	}
	close(p.queue)
	done := make(chan struct{})
	go func() {
		p.wg.Wait()
		close(done)
	}()
	select {
	case <-done:
		p.cancel()
		return nil
	case <-ctx.Done():
		p.cancel()
		<-done
		return ctx.Err()
	}
}
