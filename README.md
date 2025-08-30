# SvelteKit Starter – Installer

This repository ships a one-shot installer that scaffolds a SvelteKit app, adds common deps, optionally merges a template, tweaks `.gitignore`, can copy shared assets from the starter repo, sets a license, and (optionally) makes a local git commit.

## 🚀 Quick start (run via curl)

> **Assumes the script lives at** `https://raw.githubusercontent.com/bchainhub/sveltekit-starter/main/sv-starter.sh`.
> If you use a different path or branch, adjust the URL accordingly.

Using curl:

```bash
curl -fsSL https://raw.githubusercontent.com/bchainhub/sveltekit-starter/main/sv-starter.sh | bash -s --
```

Or with a custom template repo:

```bash
curl -fsSL https://raw.githubusercontent.com/bchainhub/sveltekit-starter/main/sv-starter.sh \
  | bash -s -- --template https://github.com/your-org/your-template.git
````

**wget alternative:**

```bash
wget -qO- https://raw.githubusercontent.com/bchainhub/sveltekit-starter/main/sv-starter.sh | bash -s --
```

**Run locally (if you cloned this repo):**

```bash
chmod +x sv-starter.sh
./sv-starter.sh --template https://github.com/blockchainhub/sveltekit-mota.git
```

> 💡 You can pass any extra flags after `--` and they will go straight to `sv create`.

## ✅ Requirements

* **Node.js** 18+ (20+ recommended) and `npx`
* **git** (for cloning templates and committing)
* One or more package managers available (the script auto-detects): `pnpm`, `bun`, `yarn`, or `npm`
* **curl** (and optionally `rsync` for robust folder copies)

## 🧭 What the installer does (in order)

1. **Runs SvelteKit creator**
   Uses `npx sv create "$@"` to start a new project (your answers go to SvelteKit’s wizard).

2. **Detects the created project directory**
   Automatically `cd`’s into it (even if SvelteKit created a subfolder).

3. **Installs base packages**
   Installs a curated set of deps for this starter.

4. **Auth picker (interactive)**
   Choose:

   * `0` None (default)
   * `1` `@auth/sveltekit` (reminder: install your adapter)
   * `2` `lucia` (reminder: install your adapter)

   If you choose **Auth.js**, it also runs `npx auth secret`.

5. **Database / data layer picker (interactive)**
   Choose from Prisma, Drizzle ORM, Supabase, Neon, MongoDB, Redis, etc., or **None** (default).
   Some options kick off a small init step (e.g., `prisma init`, `drizzle-kit init`).

6. **(Optional) Merge a template repository**
   By default, uses:
   `https://github.com/blockchainhub/sveltekit-mota.git`
   Override with `--template <repo-url>`.

7. **Initialize git (if needed) & make a quiet scaffold commit**
   Initializes a repository if none exists and captures the initial state.

8. **Run npm-check-updates locally and clean up**
   Updates package ranges to latest, reinstalls, then removes `npm-check-updates`.

9. **Augment `.gitignore`**
   Appends extra ignores to the end of your existing `.gitignore`:

   * OS cruft: `._*`
   * Logs: `*.log`, `*.log.*`, tool-specific debug logs, `logs`, `*.pid`, …
   * Editor folders: `.idea/`, `.vscode/`, etc.
   * **Optional:** ignore lockfiles (default **Yes**). If chosen, adds common lockfiles to `.gitignore`.

10. **(Optional) Copy shared assets from this starter repo**

    * **`.editorconfig`** (default **Yes**):
      Pulled from `editors/.editorconfig` and placed at project root as `.editorconfig`.
    * **`.github`** (default **No**):
      Copies `providers/.github/` to your project root as `.github` (includes `ISSUE_TEMPLATE`).
      If retrieval fails, the installer **prints a failure and skips**—no fallback files.

11. **License selection (interactive)**
    Default is **CORE** (your org’s license). You can also choose from common SPDX licenses or **None**:

    * CORE (custom)

      * Fetches from: `https://raw.githubusercontent.com/bchainhub/core-license/refs/heads/main/LICENSE`
      * Writes to `LICENSE` and sets `package.json` → `"license": "SEE LICENSE IN LICENSE"` (npm-compliant for non-SPDX).
    * SPDX licenses (MIT, Apache-2.0, GPL-3.0-or-later, AGPL-3.0-or-later, LGPL-3.0-or-later, BSD-2/3, MPL-2.0, Unlicense, CC0-1.0, ISC, EPL-2.0)

      * Fetched from canonical text endpoints.
      * Writes to `LICENSE` and sets `package.json` → `"license": "<SPDX-ID>"`.
    * None

      * Skips creating `LICENSE` and leaves `package.json` alone.

    > If the license text can’t be fetched, the script prints an error and **does not** modify `package.json`.

12. **Final (optional) local commit**
    Prompt: “Create a single git commit with all current changes (no push)?” Default **No**.
    If **Yes**, it stages everything and commits locally. **It never pushes.**

## 🧩 Options & flags

* `--template <git-url>`
  Use a different template repository for the initial project structure.
  Example:

  ```bash
  ./sv-starter.sh --template https://github.com/your-org/your-sveltekit-template.git
  ```

* Any additional arguments after `--` are forwarded to `sv create`.
  Example:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/bchainhub/sveltekit-starter/main/sv-starter.sh \
    | bash -s -- -- --name my-app
  ```

## 📝 What to expect during prompts

* **Auth:** pick none/Auth.js/Lucia.
* **DB:** pick a data layer (or None).
* **Ignore lockfiles:** default **Yes** (adds them to `.gitignore`).
* **Copy `.editorconfig`:** default **Yes** (from `editors/.editorconfig`).
* **Copy `.github` folder:** default **No** (from `providers/.github/`).
* **License:** default **CORE**.

  * For CORE (non-SPDX) we set `package.json` → `"SEE LICENSE IN LICENSE"`.
  * For SPDX licenses we write the SPDX ID to `package.json`.
* **Final commit:** default **No** (never pushes).

## 🔐 Security note

Piping remote scripts to `bash` is convenient but sensitive. Review the script URL before running:

```bash
curl -fsSL https://raw.githubusercontent.com/bchainhub/sveltekit-starter/main/sv-starter.sh | less
```

Then run it once you’re comfortable.

## 🧯 Troubleshooting

* **“command not found: npx / pnpm / git / curl”**
  Install the missing tool and rerun.
* **Template/asset copy fails**
  The script prints a ❌ message and skips that step—no fallbacks are written.
  Check the URL/branch/path and your network access.
* **License wasn’t set in `package.json`**
  This only happens if fetching the license text failed. Fix the URL/network and rerun that step, or set `license` manually.

## 🧱 Reproducible asset copies (optional)

If you want to pin the asset copy steps to an exact commit:

* Replace the raw base:

  ```bash
  https://raw.githubusercontent.com/bchainhub/sveltekit-starter/<COMMIT_SHA>
  ```

* After cloning the starter repo, check out the same SHA before syncing:

  ```bash
  git -C "$STARTER_TMP" checkout <COMMIT_SHA> --quiet || true
  ```

## 📂 What gets created

* A SvelteKit project with your selections.
* `package.json` with updated dependencies and (optionally) `license`.
* `.gitignore` with enhanced ignores (+ optional lockfile excludes).
* Optional `.editorconfig` and `.github/ISSUE_TEMPLATE` from the starter repo.
* `LICENSE` file per your selection.

Happy hacking! ✨
