run_aws:
	nextflow run main.nf \
		-work-dir s3://olgabot-maca/nextflow-workdir-test/ \
		-bucket-dir s3://olgabot-maca/nextflow-bucket-dir-test/ \
		-with-trace -with-timeline -with-dag -with-report -latest -resume

run:
	nextflow run main.nf

run_ndnd:
	sudo nextflow run main.nf -work-dir ${HOME}/pure-scratch/nextflow/

run_aws_csv:
	pushd from-csvs
	nextflow run main.nf \
		-work-dir s3://olgabot-maca/nextflow-workdir-test/ \
		-bucket-dir s3://olgabot-maca/nextflow-bucket-dir-test/ \
		-with-trace -with-timeline -with-dag -with-report -latest -resume
	popd

run_ndnd_local:
	sudo nextflow run main.nf -work-dir ${HOME}/pure-scratch/nextflow/ \
		-process.executor='local'

test_docker:
	nextflow run -profile test,docker main.nf -ansi-log false
	nextflow run -profile test,docker main.nf --no_trimming

test_sra:
		nextflow run main.nf --sra "SRP016501"\
			--ksizes 11 \
			--log2_sketch_sizes 2 \
			--molecules dna \
			-profile docker,local


test_samplescsv:
		nextflow run main.nf --ksizes 3,9 --log2_sketch_sizes 2,3 \
			--outdir testing-output/samplescsv/ \
			--molecules dna,protein \
			--samples testing/samples.csv \
			-profile docker

test_read_pairs:
		nextflow run main.nf \
			-latest \
			--ksizes 3,9 \
			--log2_sketch_sizes 2,4 \
			--molecules dna,protein \
			--read_pairs 'testing/fastqs/*{1,2}.fastq.gz' \
			-profile docker -dump-channels

test_fastas:
		nextflow run main.nf \
			--ksizes 3,9 \
			--log2_sketch_sizes 2,4 \
			--molecules dna,protein \
			--fastas 'testing/fastas/*.fasta' \
			-profile docker


test: test_read_pairs test_fastas test_samplescsv test_sra



docker: docker_build docker_push

docker_build:
	@docker build \
		--build-arg VCS_REF=`git rev-parse --short HEAD`  \
		--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		-t czbiohub/nf-kmer-similarity .

docker_push:
	sudo docker login
	sudo docker push czbiohub/nf-kmer-similarity
	docker images
