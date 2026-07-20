# wgs-clinical-variant-calling-pipeline
Standalone germline/somatic variant identification pipeline optimized for restricted server environments.
================================================================================
  CLINICAL VARIANT DISCOVERY PIPELINE (BWA-MEM + BCFtools / GATK4)
================================================================================

An end-to-end, multi-threaded Next-Generation Sequencing (NGS) pipeline 
engineered for high-performance computing (HPC) environments. This project 
demonstrates standalone pipeline execution on a rootless Linux server, 
processing raw genomic data from SRR27892070 aligned against the RB20 
Reference Genome.

It features dual-variant discovery strategies: a high-speed lightweight 
workflow using BCFtools and a gold-standard clinical workflow using GATK4 
HaplotypeCaller.


--------------------------------------------------------------------------------
1. GLOBAL ENVIRONMENT & TOOL SETUP
--------------------------------------------------------------------------------

To avoid pointing to hardcoded absolute paths during script execution, all tool 
bin directories and runtime wrappers are exported globally to ~/.bashrc.

Commands executed for setup:
  export PATH="$HOME/internship_projects/life-science/sratoolkit.3.4.1-ubuntu64/bin:$PATH"
  export PATH="$HOME/internship_projects/life-science/FastQC:$PATH"
  export PATH="$HOME/internship_projects/life-science/bwa:$PATH"
  export PATH="$HOME/internship_projects/life-science/samtools:$PATH"
  export PATH="$HOME/internship_projects/life-science/bcftools:$PATH"
  alias trimmomatic="java -jar $HOME/internship_projects/life-science/trimmomatic-0.40.jar"


--------------------------------------------------------------------------------
2. REPOSITORY ARCHITECTURE
--------------------------------------------------------------------------------

clinical-variant-calling-pipeline/
│
├── 00_environment_setup/
│   └── 00_setup_env.sh          # Global PATH initialization script
├── 01_sra_download/
│   └── 01_download_sra.sh        # SRA fetch & FASTQ extraction
├── 02_qc_and_trimming/
│   └── 02_qc_and_trim.sh        # FastQC quality audit & Trimmomatic filtering
├── 03_alignment_bwa/
│   └── 03_align_bwa.sh          # Reference indexing & multi-threaded BWA-MEM alignment
├── 04_samtools_processing/
│   └── 04_process_samtools.sh   # SAM/BAM sorting, indexing, and alignment statistics
├── 05_variant_calling/
│   └── 05_call_variants.sh      # BCFtools mpileup & variant calling
├── 06_gatk_variant_calling/
│   └── 06_gatk_pipeline.sh      # GATK4 Read Grouping, MarkDuplicates, & HaplotypeCaller
└── README.txt


--------------------------------------------------------------------------------
3. DETAILED WORKFLOW BREAKDOWN
--------------------------------------------------------------------------------

[STAGE 0] Environment Setup
- Directory: 00_environment_setup/
- Script: 00_setup_env.sh
- Purpose: Appends tool binaries (bwa, samtools, bcftools, sratoolkit, fastqc) 
  to the user's PATH variable permanently, enabling clean execution without 
  full path prefixing.

--------------------------------------------------------------------------------

[STAGE 1] Data Retrieval
- Directory: 01_sra_download/
- Script: 01_download_sra.sh
- Description: Downloads raw sequencing run archives directly from the NCBI 
  Sequence Read Archive (SRA) and extracts paired-end FASTQ files.

Script Commands:
  #!/bin/bash
  prefetch SRR27892070
  fasterq-dump -e 32 --split-files SRR27892070

Command Breakdown:
  - prefetch: Downloads the .sra container file from SRA servers.
  - fasterq-dump -e 32: Uses 32 CPU cores for fast decompression.
  - --split-files: Splits paired-end sequencing reads into two files (_1.fastq and _2.fastq).

--------------------------------------------------------------------------------

[STAGE 2] Quality Control & Adapter Trimming
- Directory: 02_qc_and_trimming/
- Script: 02_qc_and_trim.sh
- Description: Assesses read quality parameters (Phred scores, GC content, 
  adapter contamination) and removes low-quality bases.

Script Commands:
  #!/bin/bash
  fastqc SRR27892070_1.fastq SRR27892070_2.fastq
  java -jar /home/intern/internship_projects/life-science/trimmomatic-0.40.jar PE -phred33 \
    SRR27892070_1.fastq SRR27892070_2.fastq \
    SRR27892070_1_paired.fastq SRR27892070_1_unpaired.fastq \
    SRR27892070_2_paired.fastq SRR27892070_2_unpaired.fastq \
    ILLUMINACLIP:/home/intern/internship_projects/life-science/Trimmomatic/adapters/TruSeq3-PE.fa:2:30:10 \
    LEADING:5 TRAILING:5 SLIDINGWINDOW:4:20 MINLEN:36

Command Breakdown:
  - fastqc: Generates interactive HTML base-quality profiles.
  - PE -phred33: Processes paired-end reads using standard Illumina Phred+33 quality encoding.
  - ILLUMINACLIP: Cuts Illumina TruSeq adapter sequences.
  - LEADING:5 / TRAILING:5: Trims low-quality bases (Q < 5) from read ends.
  - SLIDINGWINDOW:4:20: Scans in 4-bp windows, trimming when average quality drops below Q20.
  - MINLEN:36: Discards reads shorter than 36 bp after trimming.

--------------------------------------------------------------------------------

[STAGE 3] Genome Alignment
- Directory: 03_alignment_bwa/
- Script: 03_align_bwa.sh
- Description: Indexes the reference sequence and maps trimmed reads onto 
  the RB20 assembly.

Script Commands:
  #!/bin/bash
  bwa index ~/internship_projects/life-science/RB20/RB20_Genome.fasta
  bwa mem -t 32 ~/internship_projects/life-science/RB20/RB20_Genome.fasta \
    SRR27892070_1_paired.fastq \
    SRR27892070_2_paired.fastq > output.sam

Command Breakdown:
  - bwa index: Builds the Burrows-Wheeler Transform (BWT) index required for read alignment.
  - bwa mem -t 32: Uses 32 threads to perform seed-maximal exact match alignment.
  - > output.sam: Redirects alignment streams into SAM format.

--------------------------------------------------------------------------------

[STAGE 4] SAM/BAM Processing & Quality Metrics
- Directory: 04_samtools_processing/
- Script: 04_process_samtools.sh
- Description: Converts human-readable SAM files into compressed, 
  coordinate-sorted BAM files for fast spatial indexing.

Script Commands:
  #!/bin/bash
  samtools sort -@ 32 -o sorted_output.bam output.sam
  samtools index sorted_output.bam
  samtools flagstat sorted_output.bam > alignment_stats.txt

Command Breakdown:
  - samtools sort -@ 32: Uses 32 threads to convert SAM to binary BAM format sorted by genomic coordinates.
  - samtools index: Generates .bam.bai file for random region access.
  - samtools flagstat: Generates alignment rate metrics, mapping percentages, and proper-pair metrics.

--------------------------------------------------------------------------------

[STAGE 5] Rapid Variant Calling with BCFtools
- Directory: 05_variant_calling/
- Script: 05_call_variants.sh
- Description: Generates genotype likelihoods and identifies single nucleotide 
  polymorphisms (SNPs) and insertions/deletions (indels).

Script Commands:
  #!/bin/bash
  bcftools mpileup --threads 32 -f ~/internship_projects/life-science/RB20/RB20_Genome.fasta sorted_output.bam | \
  bcftools call --threads 32 --ploidy 1 -mv -Ob -o variants.bcf
  bcftools view variants.bcf > final_variants.vcf
  bcftools stats variants.bcf > variant_stats.txt
  cat variant_stats.txt | grep -A 10 "SNPs"

Command Breakdown:
  - bcftools mpileup: Calculates base coverage alignment metrics across genome positions.
  - bcftools call --ploidy 1: Performs variant calling using a haploid model.
  - -m: Enables multi-allelic caller algorithm.
  - -v: Outputs variant sites only.
  - bcftools stats: Extracts overall SNP and Indel counts.

--------------------------------------------------------------------------------

[STAGE 6] Clinical-Grade GATK4 Pipeline
- Directory: 06_gatk_variant_calling/
- Script: 06_gatk_pipeline.sh
- Description: Implements GATK Best Practices for clinical-grade variant discovery 
  using local de novo re-assembly.

Script Commands:
  #!/bin/bash
  gatk CreateSequenceDictionary -R ~/internship_projects/life-science/RB20/RB20_Genome.fasta
  gatk AddOrReplaceReadGroups \
    -I sorted_output.bam \
    -O rg_sorted_output.bam \
    -RGID SRR27892070 \
    -RGLB lib1 \
    -RGPL ILLUMINA \
    -RGPU unit1 \
    -RGSM SRR27892070
  gatk MarkDuplicates \
    -I rg_sorted_output.bam \
    -O dedup_output.bam \
    -M marked_dup_metrics.txt
  samtools index dedup_output.bam
  gatk HaplotypeCaller \
    -R ~/internship_projects/life-science/RB20/RB20_Genome.fasta \
    -I dedup_output.bam \
    -O gatk_raw_variants.vcf
  gatk SelectVariants \
    -R ~/internship_projects/life-science/RB20/RB20_Genome.fasta \
    -V gatk_raw_variants.vcf \
    -select-type SNP \
    -O gatk_snps.vcf
  gatk VariantFiltration \
    -R ~/internship_projects/life-science/RB20/RB20_Genome.fasta \
    -V gatk_snps.vcf \
    -O gatk_filtered_snps.vcf \
    --filter-name "QDFilter" --filter-expression "QD < 2.0" \
    --filter-name "FSFilter" --filter-expression "FS > 60.0" \
    --filter-name "MQFilter" --filter-expression "MQ < 40.0"

Command Breakdown:
  - AddOrReplaceReadGroups: Injects mandatory metadata tags required by GATK engines.
  - MarkDuplicates: Flags PCR clones sharing identical genomic coordinates to avoid false confidence scoring.
  - HaplotypeCaller: Re-assembles local haplotypes over active regions to reliably identify variants.
  - VariantFiltration: Applies standard quality cutoffs for Quality-by-Depth (QD < 2.0), Fisher Strand Bias (FS > 60.0), and Mapping Quality (MQ < 40.0).


--------------------------------------------------------------------------------
4. FULL EXECUTION WORKFLOW
--------------------------------------------------------------------------------

To run the entire modular pipeline end-to-end, execute each script sequentially 
from the repository root:

  # Initialize Environment
  bash 00_environment_setup/00_setup_env.sh

  # Run Workflow Steps
  bash 01_sra_download/01_download_sra.sh
  bash 02_qc_and_trimming/02_qc_and_trim.sh
  bash 03_alignment_bwa/03_align_bwa.sh
  bash 04_samtools_processing/04_process_samtools.sh
  bash 05_variant_calling/05_call_variants.sh
  bash 06_gatk_variant_calling/06_gatk_pipeline.sh

================================================================================
