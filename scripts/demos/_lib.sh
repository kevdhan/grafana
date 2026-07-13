#!/usr/bin/env bash
# Shared helpers for Field Engineer demo setup/reset scripts.
set -euo pipefail

DEMOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${DEMOS_ROOT}/../.." && pwd)"
STATE_FILE="${REPO_ROOT}/.demo-state"
DEFAULT_BASE_BRANCH="main"

demo_log() { printf '→ %s\n' "$*"; }
demo_warn() { printf '⚠ %s\n' "$*" >&2; }
demo_die() { printf '✗ %s\n' "$*" >&2; exit 1; }

require_repo_root() {
  cd "${REPO_ROOT}"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || demo_die "Not inside a git repo: ${REPO_ROOT}"
}

current_branch() {
  git branch --show-current
}

ensure_clean_worktree() {
  local force="${1:-0}"
  if [[ -n "$(git status --porcelain)" ]]; then
    if [[ "${force}" == "1" ]]; then
      demo_warn "Working tree is dirty; continuing because --force was set"
      return 0
    fi
    demo_die "Working tree is dirty. Commit/stash changes, or pass --force."
  fi
}

base_branch() {
  if git show-ref --verify --quiet "refs/heads/${DEFAULT_BASE_BRANCH}"; then
    echo "${DEFAULT_BASE_BRANCH}"
    return
  fi
  if git show-ref --verify --quiet "refs/remotes/origin/${DEFAULT_BASE_BRANCH}"; then
    echo "${DEFAULT_BASE_BRANCH}"
    return
  fi
  demo_die "Could not find base branch '${DEFAULT_BASE_BRANCH}' locally or on origin"
}

write_state() {
  local demo_id="$1"
  local branch="$2"
  local base="$3"
  cat >"${STATE_FILE}" <<EOF
DEMO_ID=${demo_id}
DEMO_BRANCH=${branch}
BASE_BRANCH=${base}
STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
  demo_log "Wrote ${STATE_FILE}"
}

read_state() {
  [[ -f "${STATE_FILE}" ]] || demo_die "No active demo state (${STATE_FILE}). Nothing to reset?"
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
  [[ -n "${DEMO_ID:-}" && -n "${DEMO_BRANCH:-}" && -n "${BASE_BRANCH:-}" ]] \
    || demo_die "Corrupt demo state file: ${STATE_FILE}"
}

clear_state() {
  rm -f "${STATE_FILE}"
  demo_log "Cleared demo state"
}

validate_demo_id() {
  local id="$1"
  [[ "${id}" =~ ^[a-z0-9][a-z0-9_-]*$ ]] \
    || demo_die "Invalid demo id '${id}'. Use lowercase letters, numbers, - or _."
}

demo_branch_name() {
  local id="$1"
  echo "demo/${id}"
}

list_known_demos() {
  local d
  for d in "${DEMOS_ROOT}"/*/ ; do
    [[ -d "${d}" ]] || continue
    local name
    name="$(basename "${d}")"
    [[ "${name}" == _* ]] && continue
    echo "${name}"
  done
}

# --- Fast spinup helpers (avoid cold go-mod / race-detector pain) ---

# Prepend local toolchains if present (this machine: ~/.local/go, ~/.local/node).
demo_ensure_local_path() {
  local go_bin="${HOME}/.local/go/bin"
  local node_bin="${HOME}/.local/node/bin"
  [[ -d "${go_bin}" ]] && case ":${PATH}:" in *":${go_bin}:"*) ;; *) PATH="${go_bin}:${PATH}" ;; esac
  [[ -d "${node_bin}" ]] && case ":${PATH}:" in *":${node_bin}:"*) ;; *) PATH="${node_bin}:${PATH}" ;; esac
  export PATH
}

demo_check_toolchain() {
  demo_ensure_local_path
  if ! command -v go >/dev/null 2>&1; then
    demo_warn "go not on PATH. Try: export PATH=\"\${HOME}/.local/go/bin:\${HOME}/.local/node/bin:\$PATH\""
    return 1
  fi
  if ! command -v node >/dev/null 2>&1; then
    demo_warn "node not on PATH. Try: export PATH=\"\${HOME}/.local/go/bin:\${HOME}/.local/node/bin:\$PATH\""
    return 1
  fi
  demo_log "Toolchain: $(go version) | node $(node -v)"
}

# Returns 0 if Grafana login is already healthy (HTTP 200).
demo_login_ok() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 \
    http://localhost:3000/login 2>/dev/null || true)"
  [[ "${code}" == "200" ]]
}

# Poll /login until 200. Usage: demo_wait_for_login [max_seconds]
demo_wait_for_login() {
  local max_secs="${1:-180}"
  local elapsed=0
  demo_log "Waiting for http://localhost:3000/login → 200 (up to ${max_secs}s)…"
  while (( elapsed < max_secs )); do
    if demo_login_ok; then
      demo_log "Grafana login healthy (200)"
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  demo_warn "Timed out waiting for /login 200 after ${max_secs}s (frontend compile alone is not enough)"
  return 1
}

# Pin durable Go caches when unset or redirected into Cursor's agent sandbox cache.
# Sandboxed Shell often sets GOMODCACHE/GOCACHE under /var/folders/.../cursor-sandbox-cache/,
# so downloads/builds do not reuse ~/go/pkg/mod or ~/Library/Caches/go-build.
demo_ensure_durable_go_caches() {
  local sandbox_marker="/cursor-sandbox-cache/"
  local default_mod="${HOME}/go/pkg/mod"
  local default_build="${HOME}/Library/Caches/go-build"

  if [[ -z "${GOMODCACHE:-}" || "${GOMODCACHE}" == *"${sandbox_marker}"* ]]; then
    export GOMODCACHE="${default_mod}"
  fi
  if [[ -z "${GOCACHE:-}" || "${GOCACHE}" == *"${sandbox_marker}"* ]]; then
    export GOCACHE="${default_build}"
  fi
}

# Warm module cache before first compile. Retries once on proxy timeout.
demo_warm_go_modules() {
  demo_ensure_local_path
  demo_ensure_durable_go_caches
  require_repo_root
  if ! command -v go >/dev/null 2>&1; then
    demo_warn "Skipping go mod download (go not found)"
    return 1
  fi
  demo_log "Warming Go modules (go mod download; GOMODCACHE=${GOMODCACHE}, GOCACHE=${GOCACHE})…"
  if go mod download; then
    demo_log "Go modules ready"
    return 0
  fi
  demo_warn "go mod download failed (often proxy.golang.org timeout); retrying once…"
  sleep 2
  if go mod download; then
    demo_log "Go modules ready (after retry)"
    return 0
  fi
  demo_warn "go mod download still failing — backend start may hang on the proxy"
  return 1
}

# --- Local Prometheus dependency (optional; for realistic datasource demos) ---

# Returns 0 if a local Prometheus is healthy on :9090.
# The devenv Prometheus block enables basic auth (web.yml → admin/admin), so
# an unauthenticated /-/healthy returns 401; always send credentials here.
demo_prometheus_ok() {
  curl -sf --connect-timeout 2 --max-time 5 \
    -u admin:admin \
    http://localhost:9090/-/healthy >/dev/null 2>&1
}

# Ensure a local Prometheus is running. Reuse-first (mirrors demo_login_ok):
#   - if :9090 already healthy → reuse, do nothing (fast path for iterations)
#   - else, if Docker is available → `make devenv sources=prometheus`
#   - else → warn and return non-zero so callers can fall back to TestData
# Never fails the whole setup: callers should `|| true` and degrade gracefully.
demo_ensure_prometheus() {
  if demo_prometheus_ok; then
    demo_log "Prometheus already healthy on :9090 — reuse"
    return 0
  fi
  if ! command -v docker >/dev/null 2>&1; then
    demo_warn "Docker not found — skipping Prometheus; demo will use TestData fallback"
    return 1
  fi
  demo_log "Starting local Prometheus (make devenv sources=prometheus)…"
  require_repo_root
  if ! make devenv sources=prometheus; then
    demo_warn "Failed to start Prometheus via devenv; falling back to TestData"
    return 1
  fi
  # Give the container a few seconds to answer /-/healthy.
  local elapsed=0
  while (( elapsed < 30 )); do
    if demo_prometheus_ok; then
      demo_log "Prometheus healthy on :9090"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  demo_warn "Prometheus did not become healthy within 30s; falling back to TestData"
  return 1
}

# Path to the demo's provisioned datasource file (gitignored under conf/provisioning).
demo_datasource_file() {
  echo "${REPO_ROOT}/conf/provisioning/datasources/demo-explore-trace.yaml"
}

# Provision Prometheus (host-published :9090) as a Grafana datasource.
# Grafana loads provisioning at startup; if reusing a running backend, callers
# can POST /api/admin/provisioning/datasources/reload.
demo_write_prometheus_datasource() {
  local file
  file="$(demo_datasource_file)"
  mkdir -p "$(dirname "${file}")"
  cat >"${file}" <<'EOF'
apiVersion: 1

# Field Engineer demo datasource (explore-trace). Gitignored, disposable.
# Host Grafana → Prometheus container's published port (localhost:9090).
# The devenv Prometheus block requires basic auth (web.yml → admin/admin).
datasources:
  - name: Prometheus
    uid: demo-explore-trace-prom
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
    basicAuth: true
    basicAuthUser: admin
    secureJsonData:
      basicAuthPassword: admin
EOF
  demo_log "Wrote datasource provisioning: ${file}"
}

# Remove the demo datasource provisioning file (used by reset).
demo_remove_prometheus_datasource() {
  local file
  file="$(demo_datasource_file)"
  if [[ -f "${file}" ]]; then
    rm -f "${file}"
    demo_log "Removed datasource provisioning: ${file}"
  fi
}

# Best-effort: ask a running Grafana to reload datasource provisioning.
demo_reload_datasource_provisioning() {
  if demo_login_ok; then
    curl -s -o /dev/null -X POST \
      -u admin:admin \
      http://localhost:3000/api/admin/provisioning/datasources/reload \
      >/dev/null 2>&1 \
      && demo_log "Requested Grafana datasource provisioning reload" \
      || demo_warn "Could not reload provisioning (restart backend to pick it up)"
  fi
}

# Print the preferred demo backend command (non-race). make run-go hardcodes -race.
demo_backend_cmd_hint() {
  cat <<'EOF'
  Fastest restart (after one successful non-race build; bin/ is gitignored):
    go build -o bin/grafana ./pkg/cmd/grafana
    ./bin/grafana server -profile -profile-addr=127.0.0.1 -profile-port=6000 -packaging=dev cfg:app_mode=development
  Prefer when no recent bin/grafana (faster for demos, no -race):
    go run ./pkg/cmd/grafana -- server -packaging=dev cfg:app_mode=development
  Or Air watcher (race only if .go-race-enabled-locally / GO_RACE):
    make run
  Avoid for cold demos:
    make run-go   # hardcodes -race → much slower first compile
  Agent Shell tip: pin GOMODCACHE=$HOME/go/pkg/mod and GOCACHE=$HOME/Library/Caches/go-build
  (or call demo_ensure_durable_go_caches); prefer unsandboxed shell for download/build.
EOF
}
