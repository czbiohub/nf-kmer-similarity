# nf-core/nf-kmer-similarity: Changelog

## v1.1dev

* Add option to use Dayhoff encoding for sourmash
* Add `ska` and `seqtk` to container dependencies

## v1.0 - 6 March 2019

Initial release of nf-core/nf-kmer-similarity, created with the [nf-core](http://nf-co.re/) template.

## v1.1dev - 9 September 2019

#### Pipeline Updates
* Added fastq subsampling/truncating optional parameter using [seqtk](https://github.com/lh3/seqtk)
* Added support for kmer comparisons using Split Kmer Analysis [SKA](https://github.com/simonrharris/SKA)

#### Dependency Updates
* seqtk -> 1.3
* ska -> 1.0
