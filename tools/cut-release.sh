#!/usr/bin/env bash
set -euo pipefail
: "${VERSION:?set VERSION=X.Y.Z}"
DATE="$(date +%F)"
REPO="patrickdoane/AltClickStatus"

awk -v ver="$VERSION" -v date="$DATE" -v repo="$REPO" '
BEGIN{inU=0; n=0; prev=""}
function print_template(){
  print "## [Unreleased]"
  print "### Added\n- "
  print "\n### Changed\n- "
  print "\n### Fixed\n- "
  print "\n### Removed\n- "
  print "\n### Notes for Users\n- "
  print "\n### Dev / CI\n- "
}
/^##[ \t]*\[Unreleased\]/ { print; inU=1; next }
inU && /^---/ {
  print ""; print "---"; print "";
  print "## [v" ver "] - " date
  for(i=1;i<=n;i++) print buf[i]
  print ""
  if(prev!="") print "[Compare v" prev "...v" ver "](https://github.com/" repo "/compare/v" prev "...v" ver ")"
  print ""; print_template(); inU=0; next
}
{
  if(inU){ buf[++n]=$0 } else { print }
  if($0 ~ /^##[ \t]*\[v[0-9]+\.[0-9]+\.[0-9]+\]/ && prev==""){
    match($0, /\[v([0-9]+\.[0-9]+\.[0-9]+)\]/, m); if(m[1]!="") prev=m[1];
  }
}
END{
  if(inU){
    print ""; print "---"; print "";
    print "## [v" ver "] - " date
    for(i=1;i<=n;i++) print buf[i]
    print ""
    if(prev!="") print "[Compare v" prev "...v" ver "](https://github.com/" repo "/compare/v" prev "...v" ver ")"
    print ""; print_template()
  }
}
' CHANGELOG.md > CHANGELOG.md.new

mv CHANGELOG.md.new CHANGELOG.md
echo "Cut release v$VERSION in CHANGELOG.md"
