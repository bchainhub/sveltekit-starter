#!/usr/bin/env bash
set -euo pipefail

# Defensive programming: ensure all variables are properly initialized
# This prevents "unbound variable" errors when running via bash -c
# Using simple assignment instead of declare -g for better compatibility
picked=""
pkgs=""
choice=""
auth_choice=""
exclude_lockfiles=""
copy_editorconfig=""
copy_github=""
lic_choice=""
final_commit=""
do_push=""

TEMPLATE_URL="https://github.com/bchainhub/sveltekit-mota.git"
# Starter repo (for editors/.editorconfig and providers/.github)
STARTER_REPO_GIT="https://github.com/bchainhub/sveltekit-starter.git"
STARTER_REPO_RAW="https://cdn.jsdelivr.net/gh/bchainhub/sveltekit-starter"

# ------------------ parse flags ----------------------------------------------
pass_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --template) TEMPLATE_URL="${2:-}"; shift 2;;
    --template=*) TEMPLATE_URL="${1#*=}"; shift;;
    *) pass_args+=("$1"); shift;;
  esac
done
if [[ ${#pass_args[@]} -gt 0 ]]; then
  set -- "${pass_args[@]}"
fi

# ------------------ snapshot BEFORE sv create --------------------------------
TMP_MARKER=""
if command -v mktemp >/dev/null 2>&1; then
  TMP_MARKER="$(mktemp 2>/dev/null || echo "/tmp/sv-starter-$$")"
else
  TMP_MARKER="/tmp/sv-starter-$$"
fi
trap 'rm -f "$TMP_MARKER" 2>/dev/null || true' EXIT
touch "$TMP_MARKER" 2>/dev/null || true

# ------------------ run official creator -------------------------------------
npx sv create "$@"
echo
echo "✅ SvelteKit project created!"
echo "Press Enter to continue with package installation and configuration..."
read -r

# ------------------ detect the created project dir ---------------------------
project_dir="."

# Try to detect the created project directory
if [[ -f svelte.config.js || -f svelte.config.ts ]] && [[ -f "package.json" ]]; then
  # We're already in the project directory
  project_dir="."
else
  # Look for subdirectories that might contain the project
  if [[ -n "$TMP_MARKER" ]] && [[ -f "$TMP_MARKER" ]]; then
    # Use a more portable approach instead of mapfile
    candidates=()
    while IFS= read -r -d '' dir; do
      if [[ -f "$dir/package.json" ]] && [[ -f "$dir/svelte.config.js" || -f "$dir/svelte.config.ts" ]]; then
        candidates+=("$dir")
      fi
    done < <(find . -maxdepth 1 -mindepth 1 -type d -newer "$TMP_MARKER" -print0 2>/dev/null || true)

    if [[ ${#candidates[@]} -gt 0 ]]; then
      # Sort by modification time (newest first)
      newest_time=0
      for dir in "${candidates[@]}"; do
        if [[ -d "$dir" ]]; then
          # Cross-platform stat command for modification time
          mod_time="0"
          if stat -f "%m" "$dir" >/dev/null 2>&1; then
            # macOS/BSD
            mod_time=$(stat -f "%m" "$dir" 2>/dev/null || echo "0")
          elif stat -c "%Y" "$dir" >/dev/null 2>&1; then
            # Linux
            mod_time=$(stat -c "%Y" "$dir" 2>/dev/null || echo "0")
          fi
          if [[ "$mod_time" -gt "$newest_time" ]]; then
            newest_time="$mod_time"
            project_dir="$dir"
          fi
        fi
      done
    fi
  fi

  # Fallback: look for any directory with package.json and svelte config
  if [[ "$project_dir" == "." ]]; then
    for dir in */; do
      if [[ -d "$dir" ]] && [[ -f "$dir/package.json" ]] && [[ -f "$dir/svelte.config.js" || -f "$dir/svelte.config.ts" ]]; then
        project_dir="${dir%/}"
        break
      fi
    done
  fi
fi
project_dir="${project_dir#./}"
echo "→ Detected project directory: ${project_dir:-.}"
cd "${project_dir:-.}"

# ------------------ package manager helpers ----------------------------------
detect_pm() {
  if [[ -f pnpm-lock.yaml ]] && command -v pnpm >/dev/null 2>&1; then echo pnpm
  elif [[ -f bun.lockb ]]  && command -v bun  >/dev/null 2>&1; then echo bun
  elif [[ -f yarn.lock ]]  && command -v yarn >/dev/null 2>&1; then echo yarn
  else echo npm; fi
}
PKG_PM="$(detect_pm)"
pm_add() {
  case "$PKG_PM" in
    pnpm) pnpm add "$@" ;;
    yarn) yarn add "$@" ;;
    bun)  bun add  "$@" ;;
    *)    npm i   "$@" ;;
  esac
}
pm_add_dev() {
  case "$PKG_PM" in
    pnpm) pnpm add -D "$@" ;;
    yarn) yarn add -D "$@" ;;
    bun)  bun add  -d "$@" ;;
    *)    npm i   -D "$@" ;;
  esac
}
pm_remove() {
  case "$PKG_PM" in
    pnpm) pnpm remove "$@" ;;
    yarn) yarn remove "$@" ;;
    bun)  bun remove "$@" ;;
    *)    npm uninstall "$@" ;;
  esac
}
pm_install_all() {
  case "$PKG_PM" in
    pnpm) pnpm install ;;
    yarn) yarn install ;;
    bun)  bun install ;;
    *)    npm install ;;
  esac
}
echo "→ Using package manager: $PKG_PM"

# ------------------ install base packages (non-auth) -------------------------
pm_add @blockchainhub/blo @blockchainhub/ican @tailwindcss/vite \
       blockchain-wallet-validator device-sherlock exchange-rounding \
       lucide-svelte payto-rl tailwindcss txms.js vite-plugin-pwa

# ------------------ AUTH picker ----------------------------------------------
set +u  # allow empty user input without aborting
echo
echo "Choose an authentication system:"
echo "  0) None"
echo "  1) @auth/sveltekit"
echo "  2) Lucia (lucia)"
read -rp "Enter a number (default 0): " auth_choice
auth_choice="${auth_choice:-0}"

case "$auth_choice" in
  1)
    echo "→ Installing @auth/sveltekit"
    pm_add @auth/sveltekit
    echo "   ℹ️  Note: you must install an adapter manually (e.g., @auth/drizzle-adapter, @auth/prisma-adapter, etc.)."
    ;;
  2)
    echo "→ Installing Lucia"
    pm_add lucia
    echo "   ℹ️  Note: you must install a Lucia adapter manually (e.g., @lucia-auth/adapter-<db>) and wire session storage accordingly."
    ;;
  *)
    echo "→ No auth package selected."
    ;;
esac

# If you use Auth.js, you may also want to run:
# npx auth secret
if [[ "$auth_choice" == "1" ]]; then
  npx auth secret
fi
set -u  # back to strict mode

# ------------------ DB picker -------------------------------------------------
set +u  # relax nounset during menu building/selection

# Parallel arrays: names (printable) and their package strings (space-separated)
DB_NAMES=(
  "None"
  "Prisma"
  "Drizzle ORM"
  "Neon"
  "Supabase"
  "Firebase"
  "TypeORM"
  "Kysely"
  "Upstash Redis"
  "Azure Tables Storage"
  "DynamoDB"
  "EdgeDB"
  "Fauna"
  "Hasura"
  "Mikro ORM"
  "MongoDB"
  "Neo4j"
  "pg"
  "PouchDB"
  "Sequelize"
  "SurrealDB"
  "Unstorage"
  "Xata"
)

DB_PKGS=(
  ""                                  # None
  "prisma @prisma/client"             # Prisma
  "drizzle-orm drizzle-kit"           # Drizzle ORM
  "@neondatabase/serverless"          # Neon
  "@supabase/supabase-js"             # Supabase
  "firebase"                          # Firebase
  "typeorm reflect-metadata"          # TypeORM
  "kysely"                            # Kysely
  "@upstash/redis"                    # Upstash Redis
  "@azure/data-tables"                # Azure Tables Storage
  "@aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb"  # DynamoDB
  "edgedb"                            # EdgeDB
  "faunadb"                           # Fauna
  "graphql-request"                   # Hasura
  "@mikro-orm/core"                   # Mikro ORM
  "mongodb"                           # MongoDB
  "neo4j-driver"                      # Neo4j
  "pg"                                # pg
  "pouchdb"                           # PouchDB
  "sequelize"                         # Sequelize
  "surrealdb.js"                      # SurrealDB
  "unstorage"                         # Unstorage
  "@xata.io/client"                   # Xata
)

echo
echo "Choose a database / data layer to install:"

# Display options
for (( i=0; i<${#DB_NAMES[@]}; i++ )); do
  printf " %2d) %s\n" "$i" "${DB_NAMES[$i]}"
done

# Get user choice with proper error handling
read -rp "Enter a number (default 0 for None): " choice
choice="${choice:-0}"

# Debug: show what we received and array state
echo "→ Debug: choice='${choice}', options=${#DB_NAMES[@]}"

# Validate choice and install if valid
if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 0 && choice < ${#DB_NAMES[@]} )); then
  picked="${DB_NAMES[$choice]}"
  pkgs="${DB_PKGS[$choice]}"
  echo "→ Debug: picked='${picked}', pkgs='${pkgs}'"

  if [[ -n "$pkgs" && "$picked" != "None" ]]; then
    echo "→ Installing ${picked}: ${pkgs}"
    # shellcheck disable=SC2086  # intentional word-splitting of $pkgs
    pm_add $pkgs

    case "$picked" in
      "Prisma")
        echo "→ Initializing Prisma..."
        npx prisma init
        ;;
      "Drizzle ORM")
        echo "→ Initializing Drizzle ORM..."
        npx drizzle-kit init || true
        ;;
      *)
        echo "→ No special initialization needed for ${picked}"
        ;;
    esac
  else
    echo "→ No database selected."
  fi
else
  echo "→ Invalid choice; skipping DB install."
fi

set -u  # restore strict mode

# ------------------ clone & merge template (git-clone, overwrite files) ------
if [[ -n "${TEMPLATE_URL}" ]]; then
  echo "→ Cloning template repository…"
  TMPDIR="$(mktemp -d)"
  CLONE_DIR="${TMPDIR}/clone"

  # Normalize URL (ensure it ends with .git for git clone)
  tpl_url="${TEMPLATE_URL%.git}.git"

  if git clone --depth=1 "$tpl_url" "$CLONE_DIR"; then
    echo "→ Copying template files into project (overwrite on collision)…"
    # Use tar | tar so we get dotfiles and preserve perms; exclude the template's .git and node_modules
    (cd "$CLONE_DIR" && tar -cf - --exclude='.git' --exclude='node_modules' .) | tar -xf - -C .

    echo "→ Template copy complete."
  else
    echo "❌ Failed to clone template from: $tpl_url"
  fi

  echo "→ Cleaning cloned artifacts…"
  rm -rf "$TMPDIR"

  # Only install deps if we have a manifest
  if [[ -f "package.json" ]]; then
    echo "→ Installing dependencies after template merge…"
    pm_install_all
  else
    echo "→ Warning: package.json not found; skipping dependency installation."
  fi
fi

# ------------------ ensure git repo (no commits yet) -------------------------
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git init
  echo "→ Initialized new git repository."
fi

# ------------------ LAST STEP: ncu local install / run / uninstall -----------
echo "→ Running npm-check-updates (locally)…"
pm_add_dev npm-check-updates
npx --yes npm-check-updates -u
pm_install_all
pm_remove npm-check-updates
echo "→ npm-check-updates done and removed."

# ------------------ .gitignore handling --------------------------------------
echo
read -rp "Exclude lock files via .gitignore to keep repo cleaner and avoid cross-PM conflicts? [Y/n]: " exclude_lockfiles
exclude_lockfiles="${exclude_lockfiles:-Y}"

# Ensure .gitignore exists
touch .gitignore

append_if_missing() {
  local pattern="$1"
  local file=".gitignore"
  grep -qxF "$pattern" "$file" 2>/dev/null || echo "$pattern" >> "$file"
}

# Append new ignores at the end if not already present
echo >> .gitignore
echo "# Extra ignores (added by installer)" >> .gitignore

# OS
append_if_missing "._*"

# Logs
append_if_missing "npm-debug.log*"
append_if_missing "yarn-debug.log*"
append_if_missing "yarn-error.log*"
append_if_missing "pnpm-debug.log*"
append_if_missing "pnpm-error.log*"
append_if_missing "bun-debug.log*"
append_if_missing "lerna-debug.log*"
append_if_missing "*.log"
append_if_missing "*.log.*"
append_if_missing "logs"
append_if_missing "*.pid"
append_if_missing "*.seed"
append_if_missing "*.pid.lock"

# Editors
append_if_missing ".idea/"
append_if_missing ".vscode/"
append_if_missing ".history/"
append_if_missing ".swp"
append_if_missing "*.sublime-workspace"
append_if_missing "*.sublime-project"

# Optionally append lockfile ignores
case "$exclude_lockfiles" in
  [Yy]*|'')
    echo >> .gitignore
    echo "# Lock files (managed by installer)" >> .gitignore
    append_if_missing "package-lock.json"
    append_if_missing "pnpm-lock.yaml"
    append_if_missing "yarn.lock"
    append_if_missing "bun.lockb"
    append_if_missing "npm-shrinkwrap.json"
    append_if_missing "shrinkwrap.yaml"
    append_if_missing ".pnp.cjs"
    append_if_missing ".pnp.loader.mjs"
    ;;
  *)
    echo "→ Keeping lock files tracked."
    ;;
esac

# ------------------ Copy assets from starter repo (editors/providers) --------
#   - editors/.editorconfig -> ./.editorconfig
#   - providers/.github     -> ./.github
echo
read -rp "Copy .editorconfig from starter repo (editors/.editorconfig)? [Y/n]: " copy_editorconfig
copy_editorconfig="${copy_editorconfig:-Y}"

STARTER_TMP=""
ensure_starter_clone() {
  if [[ -z "${STARTER_TMP}" ]]; then
    STARTER_TMP="$(mktemp -d)"
    echo "→ Cloning starter assets repo…"
    if ! git clone --depth=1 "$STARTER_REPO_GIT" "$STARTER_TMP" >/dev/null 2>&1; then
      echo "❌ Failed to clone starter repo: $STARTER_REPO_GIT"
      STARTER_TMP=""
    fi
  fi
}

# Copy .editorconfig
if [[ "$copy_editorconfig" =~ ^[Yy]$ ]]; then
  if curl -fsSL "${STARTER_REPO_RAW}/editors/.editorconfig" -o .editorconfig; then
    echo "→ .editorconfig copied from editors/.editorconfig (raw)."
  else
    ensure_starter_clone
    if [[ -n "$STARTER_TMP" && -f "$STARTER_TMP/editors/.editorconfig" ]]; then
      cp "$STARTER_TMP/editors/.editorconfig" .editorconfig
      echo "→ .editorconfig copied from editors/.editorconfig (clone)."
    else
      echo "❌ Failed to obtain .editorconfig from starter repo. Skipping."
    fi
  fi
else
  echo "→ Skipped .editorconfig copy."
fi

# Copy providers/.github into project root as .github (default NO)
echo
read -rp "Copy .github (providers/.github) into project root? [y/N]: " copy_github
copy_github="${copy_github:-N}"

if [[ "$copy_github" =~ ^[Yy]$ ]]; then
  STAGING_DIR="$(mktemp -d)"
  mkdir -p "$STAGING_DIR/.github/ISSUE_TEMPLATE"
  ok=true
  curl -fsSL "${STARTER_REPO_RAW}/providers/.github/ISSUE_TEMPLATE/bug.yml"     -o "$STAGING_DIR/.github/ISSUE_TEMPLATE/bug.yml"     || ok=false
  curl -fsSL "${STARTER_REPO_RAW}/providers/.github/ISSUE_TEMPLATE/feature.yml" -o "$STAGING_DIR/.github/ISSUE_TEMPLATE/feature.yml" || ok=false
  curl -fsSL "${STARTER_REPO_RAW}/providers/.github/ISSUE_TEMPLATE/config.yml"  -o "$STAGING_DIR/.github/ISSUE_TEMPLATE/config.yml"  || ok=false
  if [[ "$ok" == false ]]; then
    ensure_starter_clone
    if [[ -n "$STARTER_TMP" && -d "$STARTER_TMP/providers/.github" ]]; then
      rsync -a "$STARTER_TMP/providers/.github"/ "$STAGING_DIR/.github"/
      ok=true
    fi
  fi
  if [[ "$ok" == true && -d "$STAGING_DIR/.github" ]]; then
    mkdir -p .github
    rsync -a "$STAGING_DIR/.github"/ .github/
    echo "→ .github assets copied into project root."
  else
    echo "❌ Failed to obtain .github assets from starter repo. Skipping."
  fi
  rm -rf "$STAGING_DIR"
else
  echo "→ Skipped .github copy."
fi

# ------------------ LICENSE handling -----------------------------------------
echo
echo "Choose a license for this project:"
echo "  0) CORE (default)"
echo "  1) MIT"
echo "  2) Apache-2.0"
echo "  3) GPL-3.0-or-later"
echo "  4) AGPL-3.0-or-later"
echo "  5) LGPL-3.0-or-later"
echo "  6) BSD-2-Clause"
echo "  7) BSD-3-Clause"
echo "  8) MPL-2.0"
echo "  9) Unlicense"
echo " 10) CC0-1.0"
echo " 11) ISC"
echo " 12) EPL-2.0"
echo " 13) None (skip)"
read -rp "Enter a number (default 0): " lic_choice
lic_choice="${lic_choice:-0}"

CORE_URL="https://raw.githubusercontent.com/bchainhub/core-license/refs/heads/main/LICENSE"
declare -A SPDX_URLS=(
  ["MIT"]="https://spdx.org/licenses/MIT.txt"
  ["Apache-2.0"]="https://www.apache.org/licenses/LICENSE-2.0.txt"
  ["GPL-3.0-or-later"]="https://spdx.org/licenses/GPL-3.0-or-later.txt"
  ["AGPL-3.0-or-later"]="https://spdx.org/licenses/AGPL-3.0-or-later.txt"
  ["LGPL-3.0-or-later"]="https://spdx.org/licenses/LGPL-3.0-or-later.txt"
  ["BSD-2-Clause"]="https://spdx.org/licenses/BSD-2-Clause.txt"
  ["BSD-3-Clause"]="https://spdx.org/licenses/BSD-3-Clause.txt"
  ["MPL-2.0"]="https://spdx.org/licenses/MPL-2.0.txt"
  ["Unlicense"]="https://spdx.org/licenses/Unlicense.txt"
  ["CC0-1.0"]="https://spdx.org/licenses/CC0-1.0.txt"
  ["ISC"]="https://spdx.org/licenses/ISC.txt"
  ["EPL-2.0"]="https://spdx.org/licenses/EPL-2.0.txt"
)

# helper: set package.json license field (if package.json exists)
# - For SPDX licenses: set to the SPDX ID (e.g., "MIT")
# - For CORE (non-SPDX): set to "SEE LICENSE IN LICENSE"
set_pkg_license() {
  local lic="$1"
  if [[ -f package.json ]]; then
    if command -v node >/dev/null 2>&1; then
      node -e "
        const fs=require('fs');
        const f='package.json';
        const j=JSON.parse(fs.readFileSync(f,'utf8'));
        j.license = '$lic';
        fs.writeFileSync(f, JSON.stringify(j,null,2) + '\n');
      "
      echo "→ package.json license set to: $lic"
    else
      echo "ℹ️ Node not found; skipping package.json license update."
    fi
  fi
}

license_pkg_value=""   # what we will write into package.json
url=""                 # license fetch URL (if SPDX)
case "$lic_choice" in
  13) echo "→ Skipping license creation." ;;
  0|"")
    if curl -fsSL "$CORE_URL" -o LICENSE; then
      echo "→ Added CORE license (LICENSE)."
      license_pkg_value="SEE LICENSE IN LICENSE"
    else
      echo "❌ Failed to fetch CORE license from $CORE_URL"
    fi
    ;;
  1)  url="${SPDX_URLS[MIT]}";              license_pkg_value="MIT" ;;
  2)  url="${SPDX_URLS[Apache-2.0]}";       license_pkg_value="Apache-2.0" ;;
  3)  url="${SPDX_URLS[GPL-3.0-or-later]}"; license_pkg_value="GPL-3.0-or-later" ;;
  4)  url="${SPDX_URLS[AGPL-3.0-or-later]}";license_pkg_value="AGPL-3.0-or-later" ;;
  5)  url="${SPDX_URLS[LGPL-3.0-or-later]}";license_pkg_value="LGPL-3.0-or-later" ;;
  6)  url="${SPDX_URLS[BSD-2-Clause]}";     license_pkg_value="BSD-2-Clause" ;;
  7)  url="${SPDX_URLS[BSD-3-Clause]}";     license_pkg_value="BSD-3-Clause" ;;
  8)  url="${SPDX_URLS[MPL-2.0]}";          license_pkg_value="MPL-2.0" ;;
  9)  url="${SPDX_URLS[Unlicense]}";        license_pkg_value="Unlicense" ;;
 10)  url="${SPDX_URLS[CC0-1.0]}";          license_pkg_value="CC0-1.0" ;;
 11)  url="${SPDX_URLS[ISC]}";              license_pkg_value="ISC" ;;
 12)  url="${SPDX_URLS[EPL-2.0]}";          license_pkg_value="EPL-2.0" ;;
  *)  url=""; license_pkg_value="";;
esac

if [[ -n "$url" ]]; then
  if curl -fsSL "$url" -o LICENSE; then
    echo "→ Added license from: $url"
  else
    echo "❌ Failed to fetch license from: $url"
    license_pkg_value=""
  fi
fi

# If we successfully set a license (CORE or SPDX), write into package.json
if [[ -n "$license_pkg_value" ]]; then
  set_pkg_license "$license_pkg_value"
fi

# ------------------ Final optional commit & push ------------------------------
echo
read -rp "Create a single git commit with all current changes? [Y/n]: " final_commit
final_commit="${final_commit:-Y}"

if [[ "$final_commit" =~ ^[Yy]$ ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # If no commits exist yet, ensure we are on a branch (git may use default main/master)
    if ! git rev-parse HEAD >/dev/null 2>&1; then
      # If HEAD is unborn, ensure we have a branch name; respect user's default branch config
      default_branch="$(git config --get init.defaultBranch || echo main)"
      git checkout -b "$default_branch" >/dev/null 2>&1 || true
    fi
    git add -A || true
    git commit -m "chore: initial scaffold and configuration" || echo "ℹ️ Nothing to commit."

    # Ask to push (default No)
    echo
    read -rp "Push this commit to origin now? [y/N]: " do_push
    do_push="${do_push:-N}"
    if [[ "$do_push" =~ ^[Yy]$ ]]; then
      if git remote get-url origin >/dev/null 2>&1; then
        current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
        git push -u origin "$current_branch" || echo "❌ Push failed. Check your credentials/remote."
      else
        echo "ℹ️ No 'origin' remote set. Add one and push manually, e.g.:"
        echo "   git remote add origin <git@host:owner/repo.git>"
        echo "   git push -u origin \$(git rev-parse --abbrev-ref HEAD)"
      fi
    else
      echo "→ Skipped push."
    fi
  else
    echo "ℹ️ Not a git repository; skipping commit/push."
  fi
else
  echo "→ Skipped final commit."
fi

# ------------------ cleanup ---------------------------------------------------
if [[ -n "${STARTER_TMP:-}" && -d "${STARTER_TMP:-}" ]]; then
  rm -rf "${STARTER_TMP}"
fi

echo "✅ Done. Project ready at: $(pwd)"
