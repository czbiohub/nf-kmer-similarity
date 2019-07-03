
def helpMessage() {
    log.info """
    ==============================================================
      _                            _       _ _         _ _
     | |_ ___ _____ ___ ___    ___|_|_____|_| |___ ___|_| |_ _ _
     | '_|___|     | -_|  _|  |_ -| |     | | | .'|  _| |  _| | |
     |_,_|   |_|_|_|___|_|    |___|_|_|_|_|_|_|__,|_| |_|_| |_  |
                                                            |___|
    ==============================================================

    Usage:

    The typical command for running the pipeline is as follows.

    With a samples.csv file containing the columns sample_id,read1,read2:

      nextflow run czbiohub/nf-kmer-similarity \
        --outdir s3://olgabot-maca/nf-kmer-similarity/ --samples samples.csv


    With read pairs in one or more semicolon-separated s3 directories:

      nextflow run czbiohub/nf-kmer-similarity \
        --outdir s3://olgabot-maca/nf-kmer-similarity/ \
        --read_pairs s3://olgabot-maca/sra/homo_sapiens/smartseq2_quartzseq/*{R1,R2}*.fastq.gz;s3://olgabot-maca/sra/danio_rerio/smart-seq/whole_kidney_marrow_prjna393431/*{R1,R2}*.fastq.gz


    With plain ole fastas in one or more semicolon-separated s3 directories:

      nextflow run czbiohub/nf-kmer-similarity \
        --outdir s3://olgabot-maca/nf-kmer-similarity/choanoflagellates_richter2018/ \
        --fastas /home/olga/data/figshare/choanoflagellates_richter2018/1_choanoflagellate_transcriptomes/*.fasta


    With SRA ids (requires nextflow v19.03-edge or greater):

      nextflow run czbiohub/nf-kmer-similarity \
        --outdir s3://olgabot-maca/nf-kmer-similarity/ --sra SRP016501


    Mandatory Arguments:
      --outdir                      Local or S3 directory to output the comparison matrix to

    Sample Arguments -- One or more of:
      --samples                     CSV file with columns id, read1, read2 for each sample
      --fastas
      --read_pairs                  Local or s3 directories containing *R{1,2}*.fastq.gz
                                    files, separated by commas
      --sra                         SRR, ERR, SRP IDs representing a project. Only compatible with
                                    Nextflow 19.03-edge or greater


    Options:
      --ksizes                      Which nucleotide k-mer sizes to use. Multiple are
                                    separated by commas. Default is '21,27,33,51'
      --molecules                   Which molecule to compare on. Default is both DNA
                                    and protein, i.e. 'dna,protein'
      --log2_sketch_sizes           Which log2 sketch sizes to use. Multiple are separated
                                    by commas. Default is '10,12,14,16'
      --one_signature_per_record    Make a k-mer signature for each record in the FASTQ/FASTA files.
                                    Useful for comparing e.g. assembled transcriptomes or metagenomes.
                                    (Not typically used for raw sequencing data as this would create
                                    a k-mer signature for each read!)
      --create_sbt_index            Create a sequence bloom tree database of all samples' k-mer signatures
      --no-compare                  Don't compare all samples and output a csv

    """.stripIndent()
}



// Show help emssage
if (params.help){
    helpMessage()
    exit 0
}

// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}



/*
 * SET UP CONFIGURATION VARIABLES
 */

 // Samples from SRA
 sra_ch = Channel.empty()
 // R1, R2 pairs from a samples.csv file
 samples_ch = Channel.empty()
 // Extract R1, R2 pairs from a directory
 read_pairs_ch = Channel.empty()
 // vanilla fastas
 fastas_ch = Channel.empty()

 // Provided SRA ids
 if (params.sra){
   sra_ch = Channel
       .fromSRA( params.sra?.toString()?.tokenize(';') )
 }
 // Provided a samples.csv file
 if (params.samples){
   samples_ch = Channel
    .fromPath(params.samples)
    .splitCsv(header:true)
    .map{ row -> tuple(row.sample_id, tuple(file(row.read1), file(row.read2)))}
 }
 // Provided fastq gz read pairs
 if (params.read_pairs){
   read_pairs_ch = Channel
     .fromFilePairs(params.read_pairs?.toString()?.tokenize(';'))
 }
 // Provided vanilla fastas
 if (params.fastas){
   fastas_ch = Channel
     .fromPath(params.fastas?.toString()?.tokenize(';'))
     .map{ f -> tuple(f.baseName, tuple(file(f))) }
 }

 sra_ch.concat(samples_ch, read_pairs_ch, fastas_ch)
  .set{ reads_ch }

// AWSBatch sanity checking
if(workflow.profile == 'awsbatch'){
    if (!params.awsqueue || !params.awsregion) exit 1, "Specify correct --awsqueue and --awsregion parameters on AWSBatch!"
    if (!workflow.workDir.startsWith('s3') || !params.outdir.startsWith('s3')) exit 1, "Specify S3 URLs for workDir and outdir parameters on AWSBatch!"
}


params.ksizes = '21,27,33,51'
params.molecules =  'dna,protein'
params.log2_sketch_sizes = '10,12,14,16'

// Parse the parameters
ksizes = params.ksizes?.toString().tokenize(',')
molecules = params.molecules?.toString().tokenize(',')
log2_sketch_sizes = params.log2_sketch_sizes?.toString().tokenize(',')


process sourmash_compute_sketch {
	tag "${custom_runName}_${sample_id}_${sketch_id}"
	publishDir "${params.outdir}/sketches", mode: 'copy'
	container 'czbiohub/nf-kmer-similarity'

	errorStrategy 'retry'
  maxRetries 3

	input:
	each ksize from ksizes
	each molecule from molecules
	each log2_sketch_size from log2_sketch_sizes
	set sample_id, file(reads) from reads_ch

	output:
  set val(sketch_id), val(molecule), val(ksize), val(log2_sketch_size), file("${sample_id}_${sketch_id}.sig") into sketches_compare, sketches_index

	script:
  sketch_id = "molecule-${molecule}_ksize-${ksize}_log2sketchsize-${log2_sketch_size}"
  molecule = molecule
  ksize = ksize
  if ( params.one_signature_per_record ){
    """
    sourmash compute \
      --num-hashes \$((2**$log2_sketch_size)) \
      --ksizes $ksize \
      --$molecule \
      --output ${sample_id}_${sketch_id}.sig \
      $read1 $read2
    """
  } else {
    """
    sourmash compute \
      --num-hashes \$((2**$log2_sketch_size)) \
      --ksizes $ksize \
      --$molecule \
      --output ${sample_id}_${sketch_id}.sig \
      --merge '$sample_id' $reads
    """
  }

}

if (!params.no_compare){
  process sourmash_compare_sketches {
  	tag "${custom_runName}_${sketch_id}"

  	container 'czbiohub/nf-kmer-similarity'
  	publishDir "${params.outdir}/", mode: 'copy'
  	errorStrategy 'retry'
    maxRetries 3

  	input:
    set val(sketch_id), val(molecule), val(ksize), val(log2_sketch_size), file ("sketches/*.sig") \
      from sketches_compare.groupTuple(by: [0, 3])

  	output:
  	file "similarities_${sketch_id}.csv"

  	script:
  	"""
  	sourmash compare \
          --ksize ${ksize[0]} \
          --${molecule[0]} \
          --csv similarities_${sketch_id}.csv \
          --traverse-directory .
  	"""

  }
}


if (params.create_sbt_index) {
  process sourmash_index_sketches {
  	tag "${custom_runName}_${sketch_id}"

  	container 'czbiohub/nf-kmer-similarity'
  	publishDir "${params.outdir}/indexes", mode: 'copy'
  	errorStrategy 'retry'
    maxRetries 3

  	input:
    set val(sketch_id), val(molecule), val(ksize), val(log2_sketch_size), file ("sketches/*.sig") \
      from sketches_index.groupTuple(by: [0, 3])

  	output:
  	file "${sketch_id}.sbt.json"
    file ".sbt.${sketch_id}"

  	script:
  	"""
  	sourmash index \
          --ksize ${ksize[0]} \
          --${molecule[0]} \
          --traverse-directory $sketch_id .
  	"""

  }
}
