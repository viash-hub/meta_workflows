nextflow.enable.dsl=2
targetDir = params.rootDir + "/target"

include { demultiplex_htrnaseq } from targetDir + "/nextflow/demultiplex_htrnaseq/main.nf"
include { check_eset } from targetDir + "/dependencies/vsh/vsh/htrnaseq/main/nextflow/integration_test_components/htrnaseq/check_eset/main.nf"


params.resources_test = "gs://viash-hub-resources/demultiplex/v3/demultiplex_htrnaseq_meta/"

workflow test_wf {
  resources_test_file = file(params.resources_test)
  input_ch = Channel.fromList([
      [
          id: "sample_one",
          input: resources_test_file.resolve("SingleCell-RNA_P3_2"),
          run_information: resources_test_file.resolve("SingleCell-RNA_P3_2/SampleSheet.csv"),
          demultiplexer: "bclconvert",
          barcodesFasta: resources_test_file.resolve("barcodes.fasta"),
          genomeDir: resources_test_file.resolve("gencode.v41.star.sparse"),
          annotation: resources_test_file.resolve("gencode.v41.annotation.gtf.gz")
      ]
    ])
    | map{ state -> [state.id, state] }
    | view { "Input: $it" }
    | demultiplex_htrnaseq.run(
        toState: [
            "eset": "eset",
            "star_output": "star_output",
        ]
    )
    | check_eset.run(
        runIf: {id, state -> id == "sample_one"},
        toState: [
            "eset": "eset",
            "star_output": "star_output"
        ]
    )
}

