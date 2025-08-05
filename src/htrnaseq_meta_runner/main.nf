def date = new Date().format('yyyyMMdd_hhmmss')

def viash_config = java.nio.file.Paths.get("${moduleDir}/_viash.yaml")
def version = get_version(viash_config)

workflow run_wf {
  take:
    input_ch

  main:
    assertion_ch = input_ch
      | map { id, state ->
        if ( state.mode == "run" ) {
          println("Running in run mode")
          // Run mode means that demulitplex should run.
          assert state.input != null: "In run mode, input should point to the sequencing files"
          assert state.fastq_input == null: "In run mode, fastqs are generated and should not be provided as input\n  -> fastq_input: ${state.fastq_input}"
        } else {
          println("Running in pick mode")
          assert state.input == null: "In pick mode, raw input is not needed\n  -> input: ${state.input}"
          assert state.fastq_input != null: "In pick mode, fastq_input should point to the existing fastqs"
        }
      }

    // Should demuliplexing run, or not?
    demux_run_ch = input_ch
      | view{ "==== run mode ====" }
      | demultiplex_runner.run(
        filter: { id, state -> state.mode == "run" },
        fromState: 
          [
            "input": "input",
            "run_information": "run_information",
            "demultiplexer": "demultiplexer",
            "skip_copy_complete_check": "skip_copycomplete_check",
          ],
        toState: { id, result, state -> state + result },
      )

    demux_donot_run_ch = input_ch
      | filter{ id, state -> state.mode == "pick" }
      | view{ "==== pick mode ====" }
      | map { id, state -> [ id, state + [ fastq_output: file(state.fastq_input) ] ] }

    intermediate_ch = demux_run_ch
      | mix(demux_donot_run_ch)

    ht_ch = intermediate_ch
      | htrnaseq_runner.run(
        fromState: [
          "input": "fastq_output",
          "barcodesFasta": "barcodesFasta",
          "genomeDir": "genomeDir",
          "annotation": "annotation",
          "ignore": "ignore",
          "umi_length": "umi_length",
          "run_params": "run_params",
          "project_id": "project_id",
          "experiment_id": "experiment_id",
          "fastq_publish_dir": "fastq_publish_dir",
          "results_publish_dir": "results_publish_dir"
        ],
        toState: { id, result, state -> state + result }
      )

    output_ch = channel.empty()


  emit:
    output_ch
}

def get_version(input) {
  def inputFile = file(input)
  if (!inputFile.exists()) {
    // When executing tests
    return "unknown_version"
  }
  def yamlSlurper = new groovy.yaml.YamlSlurper()
  def loaded_viash_config = yamlSlurper.parse(inputFile)
  def version = (loaded_viash_config.version) ? loaded_viash_config.version : "unknown_version"
  println("Version to be used for main workflow: ${version}")
  return version
}
