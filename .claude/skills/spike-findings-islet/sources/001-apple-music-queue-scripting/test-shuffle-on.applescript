-- Given Music.app playing a real playlist with shuffle ON,
-- attempt the same container+index prediction and compare to actual playback order.
-- This is expected to fail/diverge since Music.app exposes no shuffle-order API.

tell application "Music"
	set origVol to sound volume
	set origShuffle to shuffle enabled

	set sound volume to 0
	set shuffle enabled to true

	play track 1 of playlist "White Girld Music"
	delay 1

	set c to container of current track
	set idx to index of current track
	set total to count of tracks of c
	set predictedFirst to name of track ((idx mod total) + 1) of c

	set beforeName to name of current track
	next track
	delay 1
	set actualNextName to name of current track
	set actualIdx to index of current track

	next track
	delay 1
	set actualNextName2 to name of current track
	set actualIdx2 to index of current track

	-- restore
	pause
	set sound volume to origVol
	set shuffle enabled to origShuffle

	return "playlist=" & (name of c) & " startIndex=" & idx & " of " & total & ¬
		linefeed & "before=" & beforeName & ¬
		linefeed & "predicted next (index+1, non-shuffle-aware)=" & predictedFirst & ¬
		linefeed & "actual next 1 after advancing=" & actualNextName & " (index=" & actualIdx & ")" & ¬
		linefeed & "actual next 2 after advancing again=" & actualNextName2 & " (index=" & actualIdx2 & ")" & ¬
		linefeed & "prediction match=" & (actualNextName is equal to predictedFirst)
end tell
