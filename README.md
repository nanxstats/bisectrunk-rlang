# Bisecting the gsDesign regression through rlang

This repository is a minimal reproduction of the downstream snapshot
regression fixed by
[keaven/gsDesign#283](https://github.com/keaven/gsDesign/pull/283).
It uses `bisectrunk` to search rlang from v1.1.7 (`7a519a2`) through `b7b9861`
while holding gsDesign and ggplot2 fixed.

## Requirements

- Git and `curl`.
- R and the toolchain required to compile R packages.
- [`bisectrunk`](https://crates.io/crates/bisectrunk) on `PATH`, for example,
  from `cargo install bisectrunk`.

The harness includes a compile-only compatibility header for R 4.6.
It exposes legacy R declarations needed by older rlang commits without
modifying their source or behavior.

## Reproduce the bisection

Run every command below from the root of this repository.

### 1. Clone the subject and downstream project

Clone both repositories normally, then detach them at the exact revisions used
by this example:

```bash
git clone https://github.com/r-lib/rlang.git rlang
git -C rlang switch --detach b7b9861df5f08b6bcb308a4dee70bf000f2304d1

git clone https://github.com/keaven/gsDesign.git gsDesign
git -C gsDesign switch --detach 67a3a74b2a370789468571083cb1db649c2618a5
```

These directories are ordinary Git clones, not submodules. They are ignored by
this repository and retain their complete local histories, including rlang's
v1.1.7 tag and every commit in the search range.

The resulting layout is:

```text
bisectrunk-rlang/
├── gsDesign/          # Fixed downstream project, before PR #283
├── rlang/             # Subject history from v1.1.7 through b7b9861
├── Makevars.r46
├── rlang-r46-compat.h
├── setup-rlang.sh
└── test-gsdesign.R
```

### 2. Prepare the fixed R inputs

Install gsDesign runtime dependencies and the two packages needed for its
focused snapshot tests:

```bash
Rscript -e 'utils::install.packages(c("remotes", "testthat", "vdiffr"), repos = "https://cloud.r-project.org/")'
Rscript -e 'remotes::install_deps("./gsDesign", dependencies = NA, upgrade = "never")'
```

Download the exact ggplot2 source used by the experiment. It will be installed
again inside every candidate environment to make sure that no worker reuses a
ggplot2 installation built under a different rlang:

```bash
mkdir -p .sources
curl -L --fail \
  -o .sources/ggplot2_4.0.3.tar.gz \
  https://github.com/cran/ggplot2/archive/refs/tags/4.0.3.tar.gz
```

Install the pre-fix gsDesign checkout once into a fixed local library:

```bash
mkdir -p .gsdesign-lib
R CMD INSTALL --library="$PWD/.gsdesign-lib" ./gsDesign
```

### 3. Run bisectrunk

```bash
bisectrunk bisect \
  --repo "$PWD/rlang" \
  --project "$PWD/gsDesign" \
  --good v1.1.7 \
  --bad b7b9861 \
  --setup '../setup-rlang.sh' \
  --run 'Rscript ../test-gsdesign.R' \
  --env "GSDESIGN_LIB=$PWD/.gsdesign-lib" \
  --jobs 4 \
  --timeout 10m \
  --run-dir "$PWD/.bisectrunk-run" \
  --cache-dir "$PWD/.bisectrunk-cache"
```

The paths passed to `--repo`, `--project`, `--run-dir`, and `--cache-dir` are
absolute intentionally. Hooks run with `gsDesign` as their working directory,
so the two hook paths refer back to the harness in its parent directory.

## What the harness controls

- `setup-rlang.sh` installs the candidate rlang and ggplot2 4.0.3 into that
  commit's private `BISECTRUNK_ENV`.
- `Makevars.r46` and `rlang-r46-compat.h` expose legacy declarations only when
  running R 4.6 or later.
- `test-gsdesign.R` places the fixed gsDesign library and candidate environment
  at the front of `.libPaths()`. This prevents a user-level `.Renviron` from
  selecting another rlang.
- The test script selects only the two affected `test_that()` blocks by exact
  description; it does not run either complete test file or the full suite.
- Each worker receives private copies of the two tests and SVG baselines below
  `BISECTRUNK_OUT`, preventing parallel vdiffr processes from racing over the
  same `.new.svg` files.
- `NOT_CRAN=true` is set explicitly because these vdiffr comparisons are
  skipped in CRAN mode.
- A matching snapshot exits 0 and is classified as good. A changed snapshot
  exits 1 and is classified as bad.

bisectrunk caches completed candidate installations in `.bisectrunk-cache`.
After an interruption, use the `bisectrunk resume ...` command printed by the
CLI instead of starting over.

## Expected result

With four workers, the run evaluates 15 of the 189 commits in the range and
reports:

```text
first bad commit: 9899406c1a14252278303ba36b48ee3101d4eb83
last good commit: e58d448ee9a7cf2b1fa8d50e2d93424bbce636d0
```

The first bad commit is **Implement `hash()` with our own walker**.
