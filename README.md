# port-protector

A minimal daemon that occupies a specific TCP port to prevent local
development services from binding to it. Useful when you're tired of
`rackup`, `rails server`, or other tools silently grabbing well-known
ports.

## Problem

Local development tools default to fixed ports (e.g., 9292 for Rack).
When multiple projects or habits converge on the same port, you get
silent conflicts, stale processes, or worse — connecting to the wrong
service. Port-protector makes the conflict loud and immediate: the
other tool fails to bind, and you know right away.

## Design

- **Language:** C (smallest binary, no runtime, no GC, ~20KB)
- **Mechanism:** `bind()` + `listen()` on the target port, then `pause()` forever
- **Resource usage:** One socket fd, one process, near-zero memory
- **Message (optional):** Accepts connections and sends a short message
  ("Port 9292 is intentionally occupied by port-protector") before
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
./port-protector

# Run on a different port
./port-protector 3000

# Run as a background daemon
./port-protector &

# Verify it works
curl localhost:9292
# => Port 9292 is intentionally occupied by port-protector

# Now rackup will fail immediately:
rackup
# => Errno::EADDRINUSE: Address already in use - bind(2) for "0.0.0.0" port 9292

# Stop
kill $(lsof -ti :9292)
```

## Build requirements

- A C compiler (cc/gcc/clang)
- POSIX system (macOS, Linux)

## Test procedure

### Quick local test (no launchd)

```sh
# Build
make clean && make

# Start on a temporary port
./port-protector 9396 &
pid=$!

# Verify response (daemon writes raw text, not HTTP)
curl --http0.9 127.0.0.1:9396

# Stop
kill "$pid"
wait "$pid" 2>/dev/null || true
```

### launchd lifecycle test (macOS)

```sh
# Install and start
sudo make install

# Verify launchd state
sudo launchctl print system/com.local.port-protector | head -n 40

# Verify port behavior
curl --http0.9 127.0.0.1:9292

# Uninstall and remove artifacts
sudo make uninstall

# Confirm service is gone
sudo launchctl print system/com.local.port-protector 2>/dev/null || true

# Confirm port is no longer occupied
curl --http0.9 --max-time 1 127.0.0.1:9292 || true
```

### Testing pitfalls

- This daemon serves plain TCP text and closes the socket; `curl` can show the message and still return a non-zero exit code.
- Use `127.0.0.1` instead of `localhost` to avoid IPv6/IPv4 ambiguity in tests.
- Prefer `sudo launchctl print system/<label>` over `launchctl list` for authoritative daemon state.

## Future ideas

- [Factor out go-away message to a constant string](https://github.com/doolin/port-protector/issues/2)
- [Configurable message via flag or env var](https://github.com/doolin/port-protector/issues/1)
- Occupy multiple ports from a config file
- launchd plist / systemd unit for auto-start
- Log connection attempts (who tried to bind?)
- Custom application icon
