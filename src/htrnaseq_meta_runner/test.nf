nextflow.enable.dsl=2
targetDir = params.rootDir + "/target"

include { htrnaseq_meta_runner } from targetDir + "/nextflow/htrnaseq_meta_runner/main.nf"

params.resources_test = "gs://viash-hub-resources/demultiplex/v3/demultiplex_htrnaseq_meta/"

workflow test_wf {
  resources_test_file = file(params.resources_test)
  input_ch = Channel.fromList([
      [
          id: "sample_one",
          mode: "run",
          project_id: "my_proj_id"
          experiment_id: "my_exp_id"

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
    | htrnaseq_meta_runner.run(
        toState: [
            "eset": "eset",
            "star_output": "star_output",
        ]
    )
}

