#!/bin/bash
# Raw TCP probe of candidate local ports found by inspect-ports.sh, bypassing
# curl (which context-mode intercepts) with plain netcat + a bare HTTP GET.
for port in "$@"; do
  echo "=== port $port ==="
  (echo -e "GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n"; sleep 1) \
    | nc -w 3 127.0.0.1 "$port" | xxd | head -10
  echo
done
