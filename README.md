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


NGS PIPELINE
NOW THAT I HAVE LINKED ALL THE TOOLS INTO OUR SERVER ENVIROMENT WE DONOT NEED TO CHANGE THE PATH DIRECTORY EACH TIME FOR EACH SPECIFIC FOLDER 
WE CAN CHOOSE OUR DEFINE FOLDER AND START GIVING THE COMMAND THE SYSYTEM WILL SEARCH AND FIND ALL THE TOOOLS BY HIMSELF AND RUN THE GIVEN COMMAND LINE 
TO SET UP THIS WE HAVE GIVEN THE COMMAND LINE FOE EACH TOOL


FOR EXAMPLE

# 1. Add sratoolkit
echo 'export PATH="$HOME/internship_projects/life-science/sratoolkit.3.4.1-ubuntu64/bin:$PATH"' >> ~/.bashrc

# 2. Add FastQC
echo 'export PATH="$HOME/internship_projects/life-science/FastQC:$PATH"' >> ~/.bashrc

# 3. Add bwa
echo 'export PATH="$HOME/internship_projects/life-science/bwa:$PATH"' >> ~/.bashrc

# 4. Add samtools
echo 'export PATH="$HOME/internship_projects/life-science/samtools:$PATH"' >> ~/.bashrc

# 5. Add bcftools
echo 'export PATH="$HOME/internship_projects/life-science/bcftools:$PATH"' >> ~/.bashrc


FOR TRIMOMATIC 

echo 'alias trimmomatic="java -jar $HOME/internship_projects/life-science/trimmomatic-0.40.jar"' >> ~/.bashrc

STEP-2 REOLAD THE TERMINAL SETTING
source ~/.bashrc



DETAILS EXPLANATION



This command does the exact same job for GATK that our earlier command did for HISAT2 and your other tools. It permanently saves the folder location of GATK into your terminal's memory so you can run gatk or gatk Mutect2 from absolutely anywhere on the server.

If you don't run this command, the server will have no idea what gatk means, and you would be forced to type out the massive full path every single time you want to use it, like this:
~/internship_projects/life-science/gatk/gatk Mutect2 [arguments]

Here is the exact, piece-by-piece breakdown of what this line is doing under the hood:

1. The Core Action: export PATH="..."
In Linux, PATH is an environment variable—essentially a master search checklist containing specific folder paths.

Whenever you type any command in your terminal (like ls, cd, gatk, or delly), Linux doesn't scan your entire computer. Instead, it instantly runs down the folder paths listed inside your PATH variable to look for a matching application file.

By using export PATH=, you are telling the system: "Hey, I am updating our master search checklist right now."

2. The Path Value: "$HOME/internship_projects/life-science/gatk:$PATH"
$HOME ➔ This is a built-in shortcut that automatically fills in your home directory path (which on your server translates to /home/intern).

/internship_projects/life-science/gatk ➔ This points directly to the brand-new folder where your GATK tools and Python wrapper scripts live.

:$PATH ➔ This is the most critical part. The colon (:) acts as a separator. By adding :$PATH at the end, you are saying: "Take my new GATK folder, put it at the very front of the line, and then paste all of my existing path folders right behind it." > Warning: If you forgot to type :$PATH, you would completely overwrite your system's memory, accidentally blocking basic Linux commands like ls, cd, and mkdir from working!

3. The Permanent Storage: >> ~/.bashrc
The terminal has a very short memory. If you just type the export command directly into your terminal window, it will work perfectly—but only until you close that terminal window or log out. The next time you open Jupyter or reconnect via SSH, the server will completely forget it.

~/.bashrc ➔ This is a hidden text file that lives in your home directory. It acts as an initialization startup script. Every single time you open a new terminal panel, log in, or start a session, the server reads and runs this file automatically to set up your environment.

>> ➔ This is the Append Operator. It opens up that hidden .bashrc file, goes all the way to the very bottom line, and cleanly pastes your export command into the file without disturbing or changing any of your other existing configurations.


choose one location
SO OUR COMMAND LINE WILL BE 
1)download sra file
prefetch SRR27892070

2)fastq file conversion
fasterq-dump SRR27892070

or

fasterq-dump -e 32 SRR27892070

fasterq-dump -e 32 --split-files SRR27892070

3)QUALITY CHECK
fastqc SRR27892070_1.fastq SRR27892070_2.fastq

4)trimming
FOR PAIRED END

 java -jar /home/intern/internship_projects/life-science/trimmomatic-0.40.jar PE -phred33 \
SRR27892070_1.fastq \
SRR27892070_2.fastq \
SRR27892070_1_paired.fastq SRR27892070_1_unpaired.fastq \
SRR27892070_2_paired.fastq SRR27892070_2_unpaired.fastq \
ILLUMINACLIP:/home/intern/internship_projects/life-science/Trimmomatic/adapters/TruSeq3-PE.fa:2:30:10 \
LEADING:5 TRAILING:5 SLIDINGWINDOW:4:20 MINLEN:36

FOR SINGLE END SRRXX.fastq file

trimmomatic SE -phred33 \
SRR27892070.fastq \
SRR27892070_clean.fastq \
LEADING:3 TRAILING:3 SLIDINGWINDOW:4:20 MINLEN:36


reference genome bwa

bwa index ~/internship_projects/life-science/RB20/RB20_Genome.fasta


for 70-15

bwa index ~/internship_projects/life-science/reference/ncbi_dataset/data/GCF_000002495.2/GCF_000002495.2_MG8_genomic.fna

NEXT 

our sequence alignment

bwa mem ~/internship_projects/life-science/RB20/RB20_Genome.fasta \
SRR27892070_1_paired.fastq \
SRR27892070_2_paired.fastq > output.sam

if we want high speed and high thread we can use it by 

bwa mem -t 32 ~/internship_projects/life-science/RB20/RB20_Genome.fasta \
SRR27892070_1_paired.fastq \
SRR27892070_2_paired.fastq > output.sam      (RB20_Genome)


 bwa mem -t 64 ~/internship_projects/life-science/reference/ncbi_dataset/data/GCF_000002495.2/GCF_000002495.2_MG8_genomic.fna \
SRR27892070_1_paired.fastq \
SRR27892070_2_paired.fastq > output.sam     (70-15)


SAMTOOL

samtools sort -@ 32 -o sorted_output.bam output.sam
samtools index sorted_output.bam
samtools flagstat sorted_output.bam > alignment_stats.txt


BCFTOOL

 bcftools mpileup --threads 32 -f ~/internship_projects/life-science/RB20/RB20_Genome.fasta sorted_output.bam | bcftools call --threads 32 -mv -Ob -o variants.bcf  (for diploid)


 bcftools mpileup --threads 32 -f ~/internship_projects/life-science/RB20/RB20_Genome.fasta sorted_output.bam | \
bcftools call --threads 32 --ploidy 1 -mv -Ob -o variants.bcf   (for haploid)


 bcftools mpileup --threads 32 -f ~/internship_projects/life-science/reference/ncbi_dataset/data/GCF_000002495.2/GCF_000002495.2_MG8_genomic.fna sorted_output.bam | \
bcftools call --threads 32 --ploidy 1 -mv -Ob -o variants.bcf


BCF TO VCF

bcftools view variants.bcf > final_variants.vcf


bcftools stats variants.bcf > variant_stats.txt
cat variant_stats.txt | grep -A 10 "SNPs"




or we can use GATK THIS IS AFTER WE GOT SORTED OUTPUT BAM FILE


1.add read group

gatk AddOrReplaceReadGroups \
  -I sorted_output.bam \
  -O sorted_rg.bam \
  -RGID 1 \
  -RGLB lib1 \
  -RGPL illumina \
  -RGPU unit1 \
  -RGSM SRR27892070


2.RUN MARK DUPLICATE
gatk MarkDuplicates \
  -I sorted_rg.bam \
  -O marked_output.bam \
  -M marked_metrics.txt

3.INDEX CLEAN BAM FILE

samtools index marked_output.bam


4.RUN VARINET CALLING

gatk HaplotypeCaller \
  -R reference.fna \
  -I marked_output.bam \
  -O SRR27892070_raw_variants.vcf


Once HaplotypeCaller finishes processing, it will generate your raw, un-filtered file: SRR27892070_raw_variants.vcf.

Raw VCF files contain thousands of false positives caused by sequencing background noise or mapping errors. Before annotating, we must perform Variant Filtration to isolate the high-confidence mutations.

Here are the final steps to clean your data and run the annotation.

Step 1: Separate SNPs and Apply GATK Hard Filters
We will extract only the single nucleotide polymorphisms (SNPs) and apply the standard GATK recommendations for hard filtering to flag low-quality calls.

Run these two commands in sequence:


# 1. Extract SNPs from the raw file
gatk SelectVariants \
  -V SRR27892070_raw_variants.vcf \
  -select-type SNP \
  -O SRR27892070_raw_snps.vcf

# 2. Filter out low-quality SNPs
gatk VariantFiltration \
  -V SRR27892070_raw_snps.vcf \
  -filter "QD < 2.0 || FS > 60.0 || MQ < 40.0 || SOR > 3.0" \
  --filter-name "LOW_QUALITY_SNP" \
  -O SRR27892070_filtered_snps.vcf




Step 2: Keep Only the "PASS" Variants
The command above doesn't delete bad variants; it just writes "LOW_QUALITY_SNP" in the FILTER column. To keep your final annotation clean, extract only the high-confidence mutations that successfully passed the filters:


gatk SelectVariants \
  -V SRR27892070_filtered_snps.vcf \
  --exclude-filtered \
  -O SRR27892070_final_variants.vcf




gene annotation

java -jar ~/internship_projects/life-science/snpEff/snpEff.jar ann \  -c ~/internship_projects/life-science/snpEff/snpEff.config \  -dataDir ~/internship_projects/life-science/snpEff/data \  -nodownload \  MG8 \  SRR27892070_final_variants.vcf > SRR27892070_annotated_fixed.vcf


