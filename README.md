# nf-kmer-similarity

This is a [Nextflow](nextflow.io) workflow for running k-mer similarity

[![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/czbiohub/nf-kmer-similarity.svg)](https://cloud.docker.com/u/czbiohub/repository/docker/czbiohub/nf-kmer-similarity)

## Usage

By default, given fasta/fastq files, this workflow will create a CSV of the estimated jaccard similarities based on overlapping k-mers.

Defaults:
- `--ksizes`: `'21,27,33,51'`
- `--molecules`: `'dna,protein'`
- `--log2_sketch_sizes`: `'10,12,14,16'`

### With a samples.csv file:

Given a comma-separated variable file with columns `sample_id,read1,read2`,
one can run the workflow with these

```
nextflow run czbiohub/nf-kmer-similarity \
  --outdir s3://olgabot-maca/nf-kmer-similarity/ \
  --samples samples.csv \
  --ksizes 21,27 \
  --log2_sketch_sizes 10,11,12 --molecules dna
```

### With R1, R2 read pairs:

```
nextflow run czbiohub/nf-kmer-similarity \
  --outdir s3://olgabot-maca/nf-kmer-similarity/ \
  --read_pairs 's3://olgabot-maca/sra/homo_sapiens/smartseq2_quartzseq/*{R1,R2}*.fastq.gz,s3://olgabot-maca/sra/danio_rerio/smart-seq/whole_kidney_marrow_prjna393431/*{1,2}.fastq.gz' \
  --ksizes 21,27 --log2_sketch_sizes 10,11,12 --molecules dna
```

### With SRA ids:

```
nextflow run czbiohub/nf-kmer-similarity \
  --outdir s3://olgabot-maca/nf-kmer-similarity/ --sra SRP016501\
  --ksizes 21,27 --log2_sketch_sizes 10,11,12 --molecules dna
```

### With fasta files:

```
nextflow run czbiohub/nf-kmer-similarity \
  --outdir s3://olgabot-maca/nf-kmer-similarity/ \
  --fastas '*.fasta' \
  --ksizes 21,27 --log2_sketch_sizes 10,11,12 --molecules dna
```

### Create an index

If you'd like to create a sequence bloom tree database index in addition to comparing all sketches, use the parameter `--create_sbt_index`:


```
nextflow run czbiohub/nf-kmer-similarity -latest -profile aws \
		--read_pairs 's3://czb-maca/Plate_seq/3_month/**{R1,R2}*.fastq.gz' \
    --create_sbt_index
```

#### Create an index and don't compare all samples_ch

To create a sequence bloom tree index instead of comparing all sketches, use both flags `--create_sbt_index` and `--no-compare`, e.g.:

```
nextflow run czbiohub/nf-kmer-similarity -latest -profile aws \
		--read_pairs 's3://czb-maca/Plate_seq/3_month/**{R1,R2}*.fastq.gz' \
    --create_sbt_index --no-compare
```
