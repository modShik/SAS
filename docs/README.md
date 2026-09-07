# docs/

## `prototype.sh`

The original single-file script the SAS OS project started from, kept verbatim
for provenance. **It is not used by the build and should not be run.** Two known
faults, among others:

- it writes into `config/hooks/normal/` several lines before creating that
  directory, so `set -e` aborts the run;
- its build-failure check pipes `lb build` into `tee` without `pipefail`, so it
  reads `tee`'s exit status and a failed build is reported as a success.

Everything it did is now expressed as data under [`../config/`](../config) and
driven by [`../scripts/build-native.sh`](../scripts/build-native.sh). See the
**Design notes** section of the [top-level README](../README.md) for the full
list of what changed and why.
