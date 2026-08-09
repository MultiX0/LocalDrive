//go:build ignore

package main

// writes the committed docker-compose.yml and Caddyfile from the same
// renderers the setup tool uses, so the two can never drift apart:
//   go run gen_defaults.go
import (
	"fmt"
	"os"

	"github.com/MultiX0/LocalDrive/server/internal/runner"
)

func main() {
	proxy := runner.ProxyConfig{Port: runner.DefaultPort}
	if err := os.WriteFile("Caddyfile", []byte(runner.RenderCaddyfile(proxy)), 0o644); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	compose := runner.RenderCompose(proxy, "./data", "./data/external")
	if err := os.WriteFile("docker-compose.yml", []byte(compose), 0o644); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Println("wrote Caddyfile and docker-compose.yml")
}
