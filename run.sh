#!/usr/bin/env bash
# Run the game locally.
#   ./run.sh          play (menu)
#   ./run.sh race     jump straight into the track
#   ./run.sh test     headless smoke test
#   ./run.sh editor   open in the Godot editor
#   ./run.sh web      export the web build to build/web
#   ./run.sh deploy   export web build and publish it to GitHub Pages (gh-pages branch)
set -euo pipefail
cd "$(dirname "$0")"

GODOT="${GODOT:-$(command -v godot || command -v godot4 || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
[ -x "$GODOT" ] || { echo "Godot 4 not found. Install it or set GODOT=/path/to/godot" >&2; exit 1; }

# First run: import assets / build class cache.
[ -d .godot ] || "$GODOT" --headless --path . --import

case "${1:-play}" in
  play)   exec "$GODOT" --path . ;;
  race)   exec "$GODOT" --path . res://scenes/tracks/offroad_track.tscn ;;
  test)   exec "$GODOT" --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn ;;
  editor) exec "$GODOT" --path . --editor ;;
  web|deploy)
    rm -rf build/web && mkdir -p build/web
    "$GODOT" --headless --path . --export-release Web build/web/index.html
    if [ "$1" = deploy ]; then
      remote="$(git remote get-url origin)"
      cd build/web && touch .nojekyll
      git init -q -b gh-pages && git add -A
      git -c commit.gpgsign=false commit -q -m "Deploy web build"
      git push -f "$remote" gh-pages  # ponytail: force-push, gh-pages holds only the latest build
    fi ;;
  *)      sed -n '2,8p' "$0"; exit 1 ;;
esac
