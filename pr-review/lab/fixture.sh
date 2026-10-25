#!/usr/bin/env bash
# PR Review smoke fixture: main plus a feature branch that adds code with clear review issues (SQL built from input, paging that drops the last page).
# Runs inside an empty temporary directory and builds the fixture there.
set -euo pipefail

git init -q
git checkout -q -b main
git config user.email fixture@example.com
git config user.name fixture
git config commit.gpgsign false
commit() { printf '%s\n' "$1" >>history.txt; git add -A; if [ -n "${2:-}" ]; then git commit -q -m "$1" -m "$2"; else git commit -q -m "$1"; fi; }
mkdir -p src
cat >src/users.js <<'JS'
export function findUser(db, id) {
  return db.query('SELECT * FROM users WHERE id = $1', [id]);
}
JS
commit "chore: initial commit"
git checkout -q -b feat/search
cat >>src/users.js <<'JS'

export function searchUsers(db, name) {
  // Build the query from user input.
  return db.query("SELECT * FROM users WHERE name LIKE '%" + name + "%'");
}

export function pageCount(total, perPage) {
  return Math.floor(total / perPage);
}
JS
commit "feat: add user search and paging"
