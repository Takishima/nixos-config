#!/bin/sh
# Nix post-build-hook: records what was built, for push-cache.sh.
# A failing hook fails the build, so this never fails.
for path in $OUT_PATHS; do
  echo "$path"
done >>/nix/var/nix/built-paths 2>/dev/null
exit 0
