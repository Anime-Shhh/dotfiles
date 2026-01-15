#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Snippet Screenshot
# @raycast.mode silent
# @raycast.packageName Custom

# Trigger the built-in macOS screenshot tool for a selection
screencapture -i ~/Downloads/Screenshots/snippet-$(date +%Y-%m-%d_%H-%M-%S).png
screencapture -i -c
