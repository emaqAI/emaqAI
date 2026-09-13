#!/bin/bash
# Skips to the next track/video in Brave (e.g. YouTube playlist/mix).
#
# Plain media keys (F7/F8/F9) are unreliable here since macOS routes them
# to whichever app currently owns the "Now Playing" session, which isn't
# always Brave even when it's the one actually playing audio. Activating
# Brave first and sending the in-page keyboard shortcut via System Events
# is what actually works, and — unlike computer-use browser automation,
# which is read-only for browser apps — plain AppleScript UI scripting
# isn't restricted that way.
osascript -e 'tell application "Brave Browser" to activate'
sleep 1
osascript -e 'tell application "System Events" to keystroke "n" using {shift down}'
