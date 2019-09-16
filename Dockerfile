FROM continuumio/anaconda3
MAINTAINER olga.botvinnik@czbiohub.org

# Suggested tags from https://microbadger.com/labels
ARG VCS_REF
LABEL org.label-schema.vcs-ref=$VCS_REF \
org.label-schema.vcs-url="e.g. https://github.com/czbiohub/nf-kmer-similarity"


WORKDIR /home

USER root

# Add user "main" because that's what is expected by this image
RUN useradd -ms /bin/bash main


ENV PACKAGES zlib1g git g++ make ca-certificates gcc zlib1g-dev libc6-dev procps libbz2-dev libcurl4-openssl-dev libssl-dev

### don't modify things below here for version updates etc.

WORKDIR /home

RUN apt-get update && \
    apt-get install -y --no-install-recommends ${PACKAGES} && \
    apt-get clean

RUN /opt/conda/bin/conda install --yes Cython bz2file pytest numpy matplotlib scipy sphinx alabaster

RUN cd /home && \
    git clone https://github.com/dib-lab/khmer.git -b master && \
    cd khmer && \
    /opt/conda/bin/python3 setup.py install && \
    /opt/conda/bin/trim-low-abund.py --version && \
    /opt/conda/bin/trim-low-abund.py --help

RUN which -a /opt/conda/bin/python3
RUN /opt/conda/bin/python3 --version
# Required for multiprocessing of 10x bam file
RUN /opt/conda/bin/pip install pathos pysam

# ENV SOURMASH_VERSION master
RUN cd /home && \
    git clone https://github.com/dib-lab/sourmash.git && \
    cd sourmash && \
    /opt/conda/bin/python3 setup.py install

RUN which -a /opt/conda/bin/python3
RUN /opt/conda/bin/python3 --version
RUN /opt/conda/bin/sourmash info
COPY docker/sysctl.conf /etc/sysctl.conf
