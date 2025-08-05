
import nextflow.exception.WorkflowScriptErrorException

def get_version(input) {
  def inputFile = file(input)
  def yamlSlurper = new groovy.yaml.YamlSlurper()
  def loaded_viash_config = yamlSlurper.parse(inputFile)
  def version = (loaded_viash_config.version) ? loaded_viash_config.version : "unknown_version"
  println("Version to be used for test workflow: ${version}")
  return version
}
// Create temporary directory for the publish_dir if it is not defined
if (!params.publish_dir && params.publishDir) {
    params.publish_dir = params.publishDir
}

if (!params.publish_dir) {
    def tempDir = Files.createTempDirectory("demultiplex_runner_integration_test")
    println "Created temp directory: $tempDir"
    // Register shutdown hook to delete it on JVM exit
    Runtime.runtime.addShutdownHook(new Thread({
        try {
            // Delete directory recursively
            Files.walk(tempDir)
                .sorted(Comparator.reverseOrder())
                .forEach { Files.delete(it) }
            println "Deleted temp directory: $tempDir"
        } catch (Exception e) {
            println "Failed to delete temp directory: $e"
        }
    }))
    params.publish_dir = tempDir
}

assert !file(params.publish_dir).isDirectory() || (file(params.publish_dir).listFiles().size() == 0), \
    "Please make sure that the publishDir is empty before running the tests!"
params.fastq_publish_dir = file("${params.publish_dir}/fastqs")
params.results_publish_dir = file("${params.publish_dir}/results")

targetDir = params.rootDir + "/target"

include { htrnaseq_meta_runner } from targetDir + "/nextflow/htrnaseq_meta_runner/main.nf"

params.resources_test = file(params.rootDir + "/resources_test")

workflow test_wf {
  resources_test_file = file(params.resources_test)
  input_ch = Channel.fromList([
      [
          id: "sample_one",
          mode: "run",
          project_id: "my_proj_id",
          experiment_id: "my_exp_id",
          fastq_publish_dir: params.fastq_publish_dir.toUriString(),
          results_publish_dir: params.results_publish_dir.toUriString(),
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
    | htrnaseq_meta_runner.run(toState: {id, result, state -> state + result})

    workflow.onComplete = {
        try {
            // Nexflow only allows exceptions generated using the 'error' function (which throws WorkflowScriptErrorException).
            // So in order for the assert statement to work (or allow other errors to let the tests to fail)
            // We need to wrap these in WorkflowScriptErrorException. See https://github.com/nextflow-io/nextflow/pull/4458/files
            // The error message will show up in .nextflow.log
            def demux_dir = files("${params.publish_dir}/SingleCell-RNA_P3_2/*_demultiplex_v?.?.?", type: 'any')
            assert demux_dir.size() == 1
            demux_dir = demux_dir[0]
            assert demux_dir.isDirectory()
            def demux_published_items = demux_dir.listFiles()
            assert demux_published_items.size() == 5
            assert demux_published_items.collect{it.name}.toSet() == ["demultiplexer_logs", "fastq", "qc", "SampleSheet.csv", "transfer_completed.txt"].toSet()
            def sample_file_basenames = [
                "SingleCell-RNA-P3-2-SI-TT-A5_S1",
                "SingleCell-RNA-P3-2-SI-TT-A5_S1",
                "SingleCell-RNA-P3-2-SI-TT-B5_S2",
                "SingleCell-RNA-P3-2-SI-TT-B5_S2",
                "SingleCell-RNA-P3-2-SI-TT-H6_S16",
                "SingleCell-RNA-P3-2-SI-TT-G5_S7",
                "SingleCell-RNA-P3-2-SI-TT-A6_S9",
                "SingleCell-RNA-P3-2-SI-TT-H6_S16",
                "SingleCell-RNA-P3-2-SI-TT-G5_S7",
                "SingleCell-RNA-P3-2-SI-TT-A6_S9",
                "Undetermined_S0",
                "SingleCell-RNA-P3-2-SI-TT-D5_S4",
                "SingleCell-RNA-P3-2-SI-TT-D5_S4",
                "SingleCell-RNA-P3-2-SI-TT-C6_S11",
                "SingleCell-RNA-P3-2-SI-TT-G6_S15",
                "SingleCell-RNA-P3-2-SI-TT-D6_S12",
                "SingleCell-RNA-P3-2-SI-TT-G6_S15",
                "SingleCell-RNA-P3-2-SI-TT-D6_S12",
                "SingleCell-RNA-P3-2-SI-TT-C6_S11",
                "SingleCell-RNA-P3-2-SI-TT-C5_S3",
                "SingleCell-RNA-P3-2-SI-TT-C5_S3",
                "SingleCell-RNA-P3-2-SI-TT-H5_S8",
                "SingleCell-RNA-P3-2-SI-TT-F5_S6",
                "SingleCell-RNA-P3-2-SI-TT-F5_S6",
                "SingleCell-RNA-P3-2-SI-TT-H5_S8",
                "SingleCell-RNA-P3-2-SI-TT-E5_S5",
                "SingleCell-RNA-P3-2-SI-TT-B6_S10",
                "SingleCell-RNA-P3-2-SI-TT-F6_S14",
                "SingleCell-RNA-P3-2-SI-TT-E6_S13",
                "SingleCell-RNA-P3-2-SI-TT-F6_S14",
                "SingleCell-RNA-P3-2-SI-TT-E6_S13",
                "SingleCell-RNA-P3-2-SI-TT-B6_S10",
                "SingleCell-RNA-P3-2-SI-TT-E5_S5",
            ]
            def fastq_files = demux_dir.resolve("fastq").listFiles()
            assert fastq_files.collect{it.name}.toSet() == sample_file_basenames.collectMany{[it + "_R1_001.fastq.gz", it + "_R2_001.fastq.gz"]}.toSet()

            def expected_fastqc_files = sample_file_basenames.collectMany{[it + "_R1_001", it + "_R2_001"]}.collectMany{[it + "_fastqc_data.txt", it + "_fastqc_report.html", it + "_summary.txt"]}
            def fastqc_files = demux_dir.resolve("qc/fastqc").listFiles()
            assert fastqc_files.collect{it.name}.toSet() == expected_fastqc_files.toSet()
            
            assert demux_dir.resolve("qc/multiqc_report.html").exists()
            assert demux_dir.resolve("SampleSheet.csv").exists()

            def well_fastq_dir = files("${params.publish_dir}/fastqs/sample_one/*_htrnaseq_v?.?.?", type: 'any')
            assert well_fastq_dir.size() == 1
            well_fastq_dir = well_fastq_dir[0]
            assert well_fastq_dir.isDirectory()
            def well_fastq_sample_dirs = well_fastq_dir.listFiles()
            assert well_fastq_sample_dirs.collect{it.name}.toSet() == sample_file_basenames.findAll{it != "Undetermined_S0"}.collect{it - ~/_S[0-9]+$/}.toSet()
            def expected_wells = [
               "E1_R2",
               "E2_R1",
               "E2_R2",
               "E1_R1",
               "B1_R2",
               "B2_R1",
               "B2_R2",
               "B1_R1",
               "unknown_R2",
               "unknown_R1",
               "C2_R2",
               "C1_R1",
               "C1_R2",
               "C2_R1",
               "A1_R2",
               "D2_R2",
               "A2_R1",
               "D1_R1",
               "D1_R2",
               "A2_R2",
               "D2_R1",
               "A1_R1"
            ]
            assert well_fastq_sample_dirs.each {well_dir ->
                assert well_dir.listFiles().collect{it.name}.toSet() == expected_wells.collect{it + "_001.fastq"}.toSet()
            }

            def results_subdir = file("${params.publish_dir}/results")
            def expected_subdir = file("${results_subdir}/my_proj_id/my_exp_id/data_processed", type: 'any')
            assert expected_subdir.isDirectory()
            def expected_result_dir = files("${expected_subdir}/*_htrnaseq_v?.?.?", type: 'any')
            assert expected_result_dir.size() == 1
            expected_result_dir = expected_result_dir[0]
            assert expected_result_dir.isDirectory()
            def expected_esets = sample_file_basenames.findAll{it != "Undetermined_S0"}.collect{it - ~/_S[0-9]+$/ + ".rds"}.toSet()
            
            def found_esets = files("${expected_result_dir}/esets/*.rds", type: 'any')
            assert found_esets.size() == 16
            assert found_esets.collect{it.name}.toSet() == expected_esets.toSet()
            expected_table_filenames = sample_file_basenames.findAll{it != "Undetermined_S0"}.collect{it - ~/_S[0-9]+$/ + ".txt"}
            def found_pdata = files("${expected_result_dir}/pData/*.txt", type: 'any')
            assert found_pdata.size() == 16
            assert found_pdata.collect{it.name}.toSet() == expected_table_filenames.toSet()
            def found_nr_genes_nr_reads = files("${expected_result_dir}/nrReadsNrGenesPerChrom/*.txt", type: 'any')
            assert found_nr_genes_nr_reads.size() == 16
            assert found_nr_genes_nr_reads.collect{it.name}.toSet() == expected_table_filenames.toSet() 
            def found_star_logs = files("${expected_result_dir}/starLogs/*.txt", type: 'any')
            assert found_star_logs.size() == 16
            assert found_star_logs.collect{it.name}.toSet() == expected_table_filenames.toSet()
            def star_output = file("${expected_result_dir}/star_output", type: 'any')
            assert star_output.isDirectory()
            
            assert files("${star_output}/*", type: 'any').collect{it.name}.toSet() == sample_file_basenames.findAll{it != "Undetermined_S0"}.collect{it - ~/_S[0-9]+$/}.toSet()
            def expected_barcodes = [
                "TCACACCTCCAAGCTA", "GTTAGTGGTCCACATA", "GAGGGATTCGGTGCAC", "CTCTCAGCACTACGGC", "CAGGGCTGTAACGCGA",
                "TCACACCAGGCTAAAT", "GGCAGTCTCTTGCAAG" ,"GACATCAAGGAAAGAC" ,"CCTCACATCGTTCTAT", "AAGCAGTGGTATCAAC"
            ]
            sample_file_basenames.findAll{it != "Undetermined_S0"}.collect{it - ~/_S[0-9]+$/}.each{
                assert files("${star_output}/${it}/*", type: 'any').collect{it.name}.toSet() == expected_barcodes.toSet()
            }
            
            assert file("${expected_result_dir}/report.html").isFile()
            assert file("${expected_result_dir}/params.yaml").isFile()
            assert file("${expected_result_dir}/fData.gencode.v41.annotation.gtf.gz.txt").isFile()

        } catch (Exception e) {
            throw new WorkflowScriptErrorException("Integration test failed!", e)
        }
    }


}

