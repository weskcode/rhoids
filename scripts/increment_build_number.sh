#!/bin/sh
set -eu

cd "${PROJECT_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"

current=""
if [ -f project.yml ]; then
  current="$(awk '/CURRENT_PROJECT_VERSION:/ { print int($2); exit }' project.yml)"
fi
if [ -z "$current" ] && [ -f RHOIDS.xcodeproj/project.pbxproj ]; then
  current="$(
    awk -F'= ' '/CURRENT_PROJECT_VERSION = / {
      gsub(/;/, "", $2)
      value = int($2)
      if (value > max) max = value
    } END { if (max > 0) print max }' RHOIDS.xcodeproj/project.pbxproj
  )"
fi

if [ -z "$current" ] || [ "$current" -lt 1 ]; then
  current=0
fi

next=$((current + 1))

echo "Auto-incrementing build number (CURRENT_PROJECT_VERSION) from $current to $next"

if [ -f project.yml ]; then
  perl -0pi -e 's/(CURRENT_PROJECT_VERSION:[ \t]*)[0-9]+/${1}'"$next"'/g' project.yml
fi
if [ -f RHOIDS.xcodeproj/project.pbxproj ]; then
  perl -0pi -e 's/(CURRENT_PROJECT_VERSION = )[0-9]+(;)/${1}'"$next"'${2}/g' RHOIDS.xcodeproj/project.pbxproj
fi
