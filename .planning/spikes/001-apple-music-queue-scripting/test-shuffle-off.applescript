-- Given Music.app playing a real playlist with shuffle OFF,
-- predict the next 5 tracks via (container of current track) + index,
-- then advance once and confirm the prediction matches reality.
-- Saves/restores volume, shuffle state, and playback state.

tell application "Music"
	set origVol to sound volume
	set origShuffle to shuffle enabled

	set sound volume to 0
	set shuffle enabled to false

	play track 2 of playlist "White Girld Music"
	delay 1

	set c to container of current track
	set idx to index of current track
	set total to count of tracks of c

	set predictedFirst to name of track (idx + 1) of c

	set beforeName to name of current track
	next track
	delay 1
	set actualNextName to name of current track

	-- restore
	pause
	set sound volume to origVol
	set shuffle enabled to origShuffle

	return "playlist=" & (name of c) & " startIndex=" & idx & " of " & total & ¬
		linefeed & "before=" & beforeName & ¬
		linefeed & "predicted next (index+1)=" & predictedFirst & ¬
		linefeed & "actual next after advancing=" & actualNextName & ¬
		linefeed & "match=" & (actualNextName is equal to predictedFirst)
end tell
