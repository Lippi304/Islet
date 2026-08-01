#!/bin/bash
# Dumps Spotify.app's AppleScript dictionary and checks for any queue/playlist/track-list API.
set -e
sdef /Applications/Spotify.app > /tmp/spotify.sdef
echo "--- queue mentions (expect none) ---"
grep -ni "queue\|up next\|playingnext" /tmp/spotify.sdef || echo "(no matches)"
echo "--- classes and elements (expect only application + single track, no list/container) ---"
grep -n "<class \|<element " /tmp/spotify.sdef
echo "--- commands ---"
grep -n "<command name=" /tmp/spotify.sdef
