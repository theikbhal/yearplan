#!/bin/bash
# One-shot: checks Xcode + gh, moves code to ~/workspace, creates public GitHub repo, builds, installs.
set -e
xcodebuild -version >/dev/null 2>&1 || { echo "Install Xcode from the App Store, open it once, accept the license, then rerun."; xcode-select --install || true; exit 1; }
command -v gh >/dev/null || brew install gh
gh auth status >/dev/null 2>&1 || gh auth login
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/workspace/YearPlan"
mkdir -p "$HOME/workspace"
if [ "$SRC" != "$DEST" ]; then mkdir -p "$DEST"; rsync -a --exclude .build --exclude build "$SRC"/ "$DEST"/; fi
cd "$DEST"
chmod +x build.sh setup.sh
printf ".build/\nbuild/\n.DS_Store\n" > .gitignore
[ -d .git ] || git init -b main
git add -A; git commit -m "YearPlan: yearly expense planner" || true
git remote get-url origin >/dev/null 2>&1 || gh repo create yearplan --public --source=. --remote=origin --push
git push -u origin main || true
./build.sh
