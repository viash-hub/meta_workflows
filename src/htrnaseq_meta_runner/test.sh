#!/bin/bash

# viash ns build --setup cb --parallel

NXF_JVM_ARGS="-XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:ActiveProcessorCount=4 -Xms4g -Xmx8g" \
  NXF_ENABLE_VIRTUAL_THREADS=1 \
  NXF_VER=24.04.6 \
  nextflow run . \
  -main-script target/nextflow/htrnaseq_meta_runner/main.nf \
  -params-file src/htrnaseq_meta_runner/example.yaml \
  -profile docker \
  -latest \
  -resume \
  -ansi-log false \
  --publish_dir test_results \
  --fastq_publish_dir test_results \
  --results_publish_dir test_results_processed
