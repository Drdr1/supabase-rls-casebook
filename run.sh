#!/usr/bin/env bash
# Runs every case twice, against vulnerable.sql and fixed.sql, each in a fresh
# database. A case passes when:
#   vulnerable: the exploit works      AND the legitimate use works
#   fixed:      the exploit is blocked AND the legitimate use still works
#
# The second half matters: a "fix" that denies everything passes any negative
# test. Every case also proves the intended user can still do their job.
#
# Connection comes from the usual libpq env vars (PGHOST, PGUSER, PGPASSWORD...).
set -euo pipefail
cd "$(dirname "$0")"

filter="${1:-}"
fail=0

printf '%-34s %-11s %-10s %-7s %s\n' CASE VARIANT EXPLOITED LEGIT RESULT
for dir in cases/*/; do
  case_name="$(basename "$dir")"
  [[ -n "$filter" && "$case_name" != *"$filter"* ]] && continue

  for variant in vulnerable fixed; do
    db="casebook_$(echo "$case_name" | tr -c 'a-z0-9\n' '_')_${variant}"
    dropdb --if-exists "$db" >/dev/null 2>&1
    createdb "$db"

    if ! out="$(psql -X -q -v ON_ERROR_STOP=1 -d "$db" \
          -f shim/supabase.sql \
          -f "$dir/$variant.sql" \
          -f "$dir/seed.sql" \
          -f "$dir/test.sql" \
          -f shim/report.psql 2>&1)"; then
      printf '%-34s %-11s %-10s %-7s %s\n' "$case_name" "$variant" - - ERROR
      echo "$out" | sed 's/^/    /'
      fail=1
      dropdb --if-exists "$db" >/dev/null 2>&1
      continue
    fi
    dropdb --if-exists "$db" >/dev/null 2>&1

    result="$(echo "$out" | grep '^RESULT ')"
    exploited="$(echo "$result" | sed -E 's/.*exploited=([tf]).*/\1/')"
    legit="$(echo "$result" | sed -E 's/.*legit=([tf]).*/\1/')"

    want_exploited=$([[ $variant == vulnerable ]] && echo t || echo f)
    if [[ "$exploited" == "$want_exploited" && "$legit" == t ]]; then
      verdict=ok
    else
      verdict=FAIL
      fail=1
    fi
    printf '%-34s %-11s %-10s %-7s %s\n' "$case_name" "$variant" \
      "$([[ $exploited == t ]] && echo yes || echo no)" \
      "$([[ $legit == t ]] && echo works || echo BROKEN)" "$verdict"
  done
done

exit "$fail"
