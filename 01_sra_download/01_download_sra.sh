#!/bin/bash
# Step 1: Download raw run SRA archive and extract paired FASTQ files

# 1. Prefetch raw SRA file from NCBI
prefetch SRR27892070

# 2. Convert and extract paired-end FASTQ reads using 32 parallel threads
fasterq-dump -e 32 --split-files SRR27892070
