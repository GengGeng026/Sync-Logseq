#!/bin/bash
set -e
HOOK_SRC="
(
d
i
r
n
a
m
e
"
(dirname"0")/../.githooks/pre-commit"
HOOK_DEST="
(
d
i
r
n
a
m
e
"
(dirname"0")/../.git/hooks/pre-commit"
if [ -f "$HOOK_SRC" ]; then
cp "
H
O
O
K
S
R
C
"
"
HOOK 
S
​
 RC""HOOK_DEST"
chmod +x "$HOOK_DEST"
echo "installed pre-commit hook"
else
echo "no .githooks/pre-commit found; ensure you place hook template there"
fi
