#!/bin/bash
# Throwaway spike script — Spotify OAuth PKCE + PUT /me/library round-trip.
# Source: Spotify for Developers — Authorization Code with PKCE flow docs
# (developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow, fetched 2026-07-20)
# and February 2026 migration guide for the PUT /me/library shape.
#
# NEVER replace CLIENT_ID below with a real value and commit it. Substitute the
# real Client ID locally/uncommitted only (env override or a local edit you revert
# afterward) — see 49-03-PLAN.md Task 2.

CLIENT_ID="<from developer.spotify.com/dashboard, D-01>"
REDIRECT_URI="http://127.0.0.1:8888/callback"   # loopback — bare "localhost" is rejected

VERIFIER=$(openssl rand -base64 96 | tr -d '\n=+/' | cut -c1-64)
CHALLENGE=$(printf '%s' "$VERIFIER" | openssl dgst -sha256 -binary | openssl base64 | tr '+/' '-_' | tr -d '=')

AUTH_URL="https://accounts.spotify.com/authorize?client_id=${CLIENT_ID}&response_type=code&redirect_uri=${REDIRECT_URI}&code_challenge_method=S256&code_challenge=${CHALLENGE}&scope=user-library-modify%20user-library-read"
open "$AUTH_URL"   # complete login in the browser, copy the ?code=... from the redirected URL

read -p "Paste the 'code' param from the redirect URL: " AUTH_CODE

TOKEN_RESPONSE=$(curl -s -X POST https://accounts.spotify.com/api/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d grant_type=authorization_code \
  -d code="$AUTH_CODE" \
  -d redirect_uri="$REDIRECT_URI" \
  -d client_id="$CLIENT_ID" \
  -d code_verifier="$VERIFIER")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')

read -p "Paste a real track URI to save (e.g. spotify:track:XXXXXXXXXXXXXXXXXXXXXX): " TRACK_URI

# Real PUT /me/library save-track call (post Feb-2026 migration shape — URI-based, not ID-based)
curl -s -X PUT https://api.spotify.com/v1/me/library \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"uris\": [\"${TRACK_URI}\"]}"
