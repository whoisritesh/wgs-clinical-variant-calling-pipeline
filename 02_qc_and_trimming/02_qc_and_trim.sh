#!/bin/bash
# Step 2: Run Quality Control via FastQC and trim low-quality adapters via Trimmomatic

# 1. Run Quality Check
fastqc SRR27892070_1.fastq SRR27892070_2.fastq

# 2. Quality & Adapter Trimming for Paired-End Reads
java -jar /home/intern/internship_projects/life-science/trimmomatic-0.40.jar PE -phred33 \
  SRR27892070_1.fastq \
  SRR27892070_2.fastq \
  SRR27892070_1_paired.fastq SRR27892070_1_unpaired.fastq \
  SRR27892070_2_paired.fastq SRR27892070_2_unpaired.fastq \
  ILLUMINACLIP:/home/intern/internship_projects/life-science/Trimmomatic/adapters/TruSeq3-PE.fa:2:30:10 \
  LEADING:5 TRAILING:5 SLIDINGWINDOW:4:20 MINLEN:36
