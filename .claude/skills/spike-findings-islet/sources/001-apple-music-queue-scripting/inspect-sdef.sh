#!/bin/bash
# Dumps Music.app's AppleScript dictionary and checks for any queue/up-next API.
set -e
sdef /System/Applications/Music.app > /tmp/music.sdef
echo "--- queue/up-next mentions (expect none) ---"
grep -ni "queue\|up next\|playingnext\|upnext" /tmp/music.sdef || echo "(no matches)"
echo "--- next/previous track commands ---"
grep -n "next track\|previous track" /tmp/music.sdef
echo "--- current playlist / track container+index properties ---"
grep -n "current playlist\|property name=\"container\"\|property name=\"index\"" /tmp/music.sdef
