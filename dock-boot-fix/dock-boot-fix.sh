#!/bin/bash
# The Dock process sometimes comes up "alive" but fails to render right
# after a fresh boot on this machine (likely the same GPU/shader boot-storm
# that hits MTLCompilerService). A clean restart of Dock a few seconds
# after login reliably fixes it, so this runs once per login as a LaunchAgent.
sleep 15
killall Dock
