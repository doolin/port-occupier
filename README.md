# port-occupier

A minimal daemon that occupies a specific TCP port to prevent local
development services from binding to it. Useful when you're tired of
`rackup`, `rails server`, or other tools silently grabbing well-known
ports.

## Problem

Local development tools default to fixed ports (e.g., 9292 for Rack).
When multiple projects or habits converge on the same port, you get
silent conflicts, stale processes, or worse — connecting to the wrong
service. Port-occupier makes the conflict loud and immediate: the
other tool fails to bind, and you know right away.

## Design

- **Language:** C (smallest binary, no runtime, no GC, ~20KB)
- **Mechanism:** `bind()` + `listen()` on the target port, then `pause()` forever
- **Resource usage:** One socket fd, one process, near-zero memory
- **Message (optional):** Accepts connections and sends a short message
  ("Port 9292 is intentionally occupied by port-occupier") before
  closing, so `curl localhost:9292` tells you what's going on

## Behavior

1. Bind to `0.0.0.0:<port>` (default 9292)
2. Listen with a small backlog
3. Optionally accept connections in a loop and write a one-line message
4. On SIGTERM/SIGINT, close the socket and exit cleanly

## Usage

```
# Build
make

# Run (default port 9292)
./port-occupier

# Run on a different port
./port-occupier 3000

# Run as a background daemon
./port-occupier &

# Verify it works
curl localhost:9292
# => Port 9292 is intentionally occupied by port-occupier

# Now rackup will fail immediately:
rackup
# => Errno::EADDRINUSE: Address already in use - bind(2) for "0.0.0.0" port 9292

# Stop
kill $(lsof -ti :9292)
```

## Build requirements

- A C compiler (cc/gcc/clang)
- POSIX system (macOS, Linux)

## Future ideas

- [Factor out go-away message to a constant string](https://github.com/doolin/port-occupier/issues/2)
- [Configurable message via flag or env var](https://github.com/doolin/port-occupier/issues/1)
- Occupy multiple ports from a config file
- launchd plist / systemd unit for auto-start
- Log connection attempts (who tried to bind?)
- Custom application icon
