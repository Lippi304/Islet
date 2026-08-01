#!/bin/bash
# Static-equivalent check: what local ports does the running Spotify process
# actually have open, before writing any client code against them.
lsof -i -P -n 2>/dev/null | grep -i spotify
