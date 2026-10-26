#!/usr/bin/env bash
# Add a new St. Bernard Happenings issue and make it the current one.
# Usage: newspaper/add-issue.sh 2026-11 "November 2026" page1.pdf page2.pdf ...
# (one PDF per page, or a single multi-page PDF)
# For reading mode, also write <id>/articles.json (and photos/) and set "articles": true in issues.json.
set -euo pipefail
id=$1; title=$2; shift 2
dir=$(cd "$(dirname "$0")" && pwd)
out=$dir/$id
mkdir -p "$out"
pdf="St_Bernard_Happenings_${title// /_}.pdf"
pdfunite "$@" "$out/$pdf" 2>/dev/null || cp "$1" "$out/$pdf"
pages=$(pdfinfo "$out/$pdf" | awk '/^Pages:/{print $2}')
read -r w h < <(pdfinfo "$out/$pdf" | awk '/^Page size:/{print int($3), int($5)}')
for n in $(seq 1 "$pages"); do
  pdftoppm -f "$n" -l "$n" -singlefile -scale-to-x 2000 -scale-to-y -1 -jpeg -jpegopt quality=82 "$out/$pdf" "$out/page-$n"
  pdftoppm -f "$n" -l "$n" -singlefile -scale-to-x 1200 -scale-to-y -1 -jpeg -jpegopt quality=80 "$out/$pdf" "$out/page-$n-1200"
done
pdftoppm -f 1 -l 1 -singlefile -scale-to-x 360 -scale-to-y -1 -jpeg -jpegopt quality=75 "$out/$pdf" "$out/thumb-1"
python3 -I - "$dir/issues.json" "$id" "$title" "$pages" "$pdf" "$w" "$h" <<'EOF'
import json, sys
path, id, title, pages, pdf, w, h = sys.argv[1:]
old = {i["id"]: i for i in json.load(open(path))}.get(id, {})
issues = [i for i in json.load(open(path)) if i["id"] != id]
issues.append({"id": id, "title": title, "pages": int(pages), "pdf": pdf, "w": int(w), "h": int(h), **({"articles": True} if old.get("articles") else {})})
issues.sort(key=lambda i: i["id"], reverse=True)
with open(path, "w") as f:
    f.write("[\n" + ",\n".join("  " + json.dumps(i) for i in issues) + "\n]\n")
EOF
echo "Added $title ($pages pages)"
