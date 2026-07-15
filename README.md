# Bisecting the gsDesign regression through rlang

This is a minimal reproduction of the downstream snapshot regression fixed by
[keaven/gsDesign#283](https://github.com/keaven/gsDesign/pull/283).
It uses `bisectrunk` to search rlang from v1.1.7 (`7a519a2`) through `b7b9861`.

## Preparation

The directory layout is:

```text
bisectrunk-rlang/
├── gsDesign/   # Checked out at 67a3a74 (before PR #283)
├── rlang/      # Contains all Git history, in particular v1.1.7 through b7b9861
├── Makevars.r46
├── rlang-r46-compat.h
├── setup-rlang.sh
└── test-gsdesign.R
```

Download the ggplot2 source package, install the pre-283 gsDesign checkout into
a local fixed library, and install its test dependencies once.
ggplot2 is installed alongside each candidate so the run never reuses a package
installation constructed under a different rlang.

```bash
Rscript -e 'utils::install.packages(c("remotes", "testthat", "vdiffr"), repos = "https://cloud.r-project.org/"); remotes::install_deps("./gsDesign", dependencies = NA, upgrade = "never")'
mkdir -p .sources
curl -L --fail -o .sources/ggplot2_4.0.3.tar.gz \
  https://github.com/cran/ggplot2/archive/refs/tags/4.0.3.tar.gz
mkdir -p .gsdesign-lib
R CMD INSTALL --library="$PWD/.gsdesign-lib" ./gsDesign
```

## Run `bisectrunk`

From this directory, run:

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

- `setup-rlang.sh` installs each rlang candidate and the fixed ggplot2 source
  into its per-commit environment.
- `Makevars.r46` and `rlang-r46-compat.h` only expose legacy declarations
  needed to compile the old endpoint with R 4.6; they do not patch candidate
  source or behavior. bisectrunk caches these environments across resumed runs.
- `test-gsdesign.R` prepends the fixed gsDesign library and `BISECTRUNK_ENV` to
  `.libPaths()` (so a user's `.Renviron` cannot override dependency selection),
  stages the two test files and their two relevant SVGs in the worker's private
  `BISECTRUNK_OUT`, then selects only the two affected `test_that()` blocks by
  exact description. The private staging directory prevents parallel workers
  from racing over vdiffr's `.new.svg` files.
- A matching old snapshot exits 0 (good); either snapshot failure exits nonzero (bad).
- `NOT_CRAN=true` is set explicitly because vdiffr snapshot comparisons are
  skipped in CRAN mode.

## Results

The run evaluates 15 of the 189 commits in the range and reports:

```text
first bad commit: 9899406c1a14252278303ba36b48ee3101d4eb83
last good commit: e58d448ee9a7cf2b1fa8d50e2d93424bbce636d0
```

The first bad commit is `Implement hash() with our own walker`.
If interrupted, continue without reinstalling completed environments
with the `bisectrunk resume ...` command printed by `bisectrunk`.
