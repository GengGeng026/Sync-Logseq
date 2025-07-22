#!/bin/bash
# Simplified Logseq Sync Script for launchd

export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync.log"

cd "$REPO_DIR" || exit 1

log() {
    # Rotate log if it's larger than 1MB
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE") -gt 1048576 ]; then
        mv "$LOG_FILE" "$LOG_FILE.old"
    fi
    echo "$(date): $1" >> "$LOG_FILE"
}

sync_repo() {
    log "Change detected, starting sync."
    
    # Ensure we are on the main branch
    git checkout main >> "$LOG_FILE" 2>&1

    # Add all changes
    git add -A >> "$LOG_FILE" 2>&1

    # Commit if there are changes
    if ! git diff --cached --quiet; then
        log "Committing local changes."
        git commit -m "Auto-sync: $(date)" >> "$LOG_FILE" 2>&1
    else
        log "No local changes to commit."
    fi

    # Pull remote changes with rebase to avoid merge commits
    log "Pulling remote changes."
    if ! git pull --rebase origin main >> "$LOG_FILE" 2>&1; then
        log "PULL FAILED: A conflict likely occurred. Please resolve it manually."
        # Abort the rebase to leave the repository in a usable state for manual fixing.
        git rebase --abort >> "$LOG_FILE" 2>&1
        return
    fi
    
    # Push the changes
    log "Pushing changes."
    if ! git push origin main >> "$LOG_FILE" 2>&1; then
        log "PUSH FAILED: Could not push to remote. Please check connection and permissions."
    fi

    log "Sync finished."
}

log "====== Sync Service Started ======"

# Initial sync on start
sync_repo

log "Starting fswatch to monitor for file changes..."

# Use fswatch to monitor the directory.
# -o batches events.
# A short sleep acts as a debounce.
fswatch -o -r --exclude="\.git/." --exclude=".*\.log$" "$REPO_DIR" | while read -r event; do
    log "fswatch event: $event"
    sleep 2 # Debounce
    sync_repo
done
