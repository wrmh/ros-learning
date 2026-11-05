#!/bin/bash
SRC="$HOME/ros-learning/notes"
DEST="$HOME/backup/$(date +%F).tar.gz"
mkdir -p "$HOME/backup"
tar -czf "$DEST" "$SRC"
echo "Backup saved to $DEST"
