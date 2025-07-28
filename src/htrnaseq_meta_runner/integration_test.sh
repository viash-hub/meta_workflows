#!/bin/bash

# get the root of the directory
REPO_ROOT=$(git rev-parse --show-toplevel)

# ensure that the command below is run from the root of the repository
cd "$REPO_ROOT"

# Make sure the workflow is built
viash ns build --setup cb --parallel

# export NXF_VER=24.04.4

set -eo pipefail

nextflow \
  run . \
  -main-script src/meta_workflows/demultiplex_htrnaseq/test.nf \
  -config src/config/labels.config \
  -entry test_wf \
  -resume \
  -profile docker,local \
  --publish_dir output

