#!/bin/bash
# Step 3: Reference Genome Indexing and Short Read Alignment

# 1. Index the reference genome (RB20_Genome)
bwa index ~/internship_projects/life-science/RB20/RB20_Genome.fasta

# 2. Perform high-speed multi-threaded alignment (32 threads)
bwa mem -t 32 ~/internship_projects/life-science/RB20/RB20_Genome.fasta \
  SRR27892070_1_paired.fastq \
  SRR27892070_2_paired.fastq > output.sam
