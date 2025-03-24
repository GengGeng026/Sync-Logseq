#!/bin/bash
cd /Users/mac/Documents/Sync-Logseq
echo "測試時間: $(date)" >> test_file.txt
git add test_file.txt
git commit -m "測試自動推送 $(date)"
git push origin main
EOL
