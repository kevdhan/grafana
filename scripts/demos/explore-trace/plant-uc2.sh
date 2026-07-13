#!/usr/bin/env bash
# Plant the Use Case 2 dropped-series demo bug on the current working tree.
#
# Why this exists: demo/explore-trace is created from origin/main, which does NOT
# include the intentional bug. Leaving the plant as leftover untracked files is
# fragile — `setup.sh --force` / a clean checkout wipes them and the agent then
# has to rediscover and recreate the bug by hand. Setup always runs this.
#
# What it plants (reversible; reset unplants):
#   - public/app/features/explore/Graph/limitSeries.ts
#       limitSeriesForDisplay caps at hardcoded 1 (not MAX_NUMBER_OF_TIME_SERIES)
#   - public/app/features/explore/Graph/limitSeries.test.ts  (fails 2/3 until fixed)
#   - GraphContainer.tsx wired to call limitSeriesForDisplay (disclaimer still uses
#       the real MAX_NUMBER_OF_TIME_SERIES constant → "shows 20 / draws 1" tell)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_lib.sh
source "${SCRIPT_DIR}/../_lib.sh"

require_repo_root

FIXTURES="${SCRIPT_DIR}/fixtures"
GRAPH_DIR="${REPO_ROOT}/public/app/features/explore/Graph"
TARGET_TS="${GRAPH_DIR}/limitSeries.ts"
TARGET_TEST="${GRAPH_DIR}/limitSeries.test.ts"
GRAPH_CONTAINER="${GRAPH_DIR}/GraphContainer.tsx"

[[ -f "${FIXTURES}/limitSeries.ts" && -f "${FIXTURES}/limitSeries.test.ts" ]] \
  || demo_die "Missing UC2 fixtures under ${FIXTURES}"
[[ -f "${GRAPH_CONTAINER}" ]] \
  || demo_die "GraphContainer.tsx not found at ${GRAPH_CONTAINER}"

cp "${FIXTURES}/limitSeries.ts" "${TARGET_TS}"
cp "${FIXTURES}/limitSeries.test.ts" "${TARGET_TEST}"
demo_log "Planted UC2 bug files: limitSeries.ts (cap=1) + limitSeries.test.ts"

# Wire GraphContainer to the helper if it still uses the inline slice.
if grep -q "limitSeriesForDisplay" "${GRAPH_CONTAINER}"; then
  demo_log "GraphContainer.tsx already imports limitSeriesForDisplay — leave wiring as-is"
else
  python3 - "${GRAPH_CONTAINER}" <<'PY'
import pathlib, sys, re
path = pathlib.Path(sys.argv[1])
text = path.read_text()

# Drop the local constant; import from limitSeries instead.
text2, n1 = re.subn(
    r"import \{ ExploreGraph \} from '\./ExploreGraph';\n"
    r"import \{ ExploreGraphLabel \} from '\./ExploreGraphLabel';\n"
    r"import \{ loadGraphStyle \} from '\./utils';\n\n"
    r"const MAX_NUMBER_OF_TIME_SERIES = 20;\n",
    "import { ExploreGraph } from './ExploreGraph';\n"
    "import { ExploreGraphLabel } from './ExploreGraphLabel';\n"
    "import { MAX_NUMBER_OF_TIME_SERIES, limitSeriesForDisplay } from './limitSeries';\n"
    "import { loadGraphStyle } from './utils';\n",
    text,
    count=1,
)
if n1 != 1:
    # Already partially patched or unexpected shape — fail loudly so setup doesn't silently skip.
    sys.stderr.write(
        "plant-uc2: could not rewrite GraphContainer imports "
        f"(matched {n1}); manual check needed\n"
    )
    sys.exit(1)

text3, n2 = re.subn(
    r"const slicedData = useMemo\(\(\) => \{\n"
    r"    return showAllSeries \? data : data\.slice\(0, MAX_NUMBER_OF_TIME_SERIES\);\n"
    r"  \}, \[data, showAllSeries\]\);",
    "const slicedData = useMemo(() => {\n"
    "    return limitSeriesForDisplay(data, showAllSeries);\n"
    "  }, [data, showAllSeries]);",
    text2,
    count=1,
)
if n2 != 1:
    sys.stderr.write(
        "plant-uc2: could not rewrite slicedData memo "
        f"(matched {n2}); manual check needed\n"
    )
    sys.exit(1)

path.write_text(text3)
print("→ Wired GraphContainer.tsx → limitSeriesForDisplay")
PY
fi

# Idempotent: if a prior Agent fix swapped 1 → MAX_NUMBER_OF_TIME_SERIES, re-break it.
if grep -q "data.length : MAX_NUMBER_OF_TIME_SERIES" "${TARGET_TS}"; then
  python3 - "${TARGET_TS}" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
text = text.replace(
    "const limit = showAllSeries ? data.length : MAX_NUMBER_OF_TIME_SERIES;",
    "const limit = showAllSeries ? data.length : 1;",
    1,
)
path.write_text(text)
print("→ Re-planted hardcoded series cap (1) in limitSeries.ts")
PY
fi

# Sanity: bug must be present.
if ! grep -q "data.length : 1" "${TARGET_TS}"; then
  demo_die "UC2 plant failed — expected hardcoded ': 1' in ${TARGET_TS}"
fi
demo_log "UC2 plant verified (limitSeriesForDisplay caps at 1; disclaimer still uses MAX=20)"
