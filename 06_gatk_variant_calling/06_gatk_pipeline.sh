#!/bin/bash
# Step 6: Clinical-grade Variant Discovery using GATK (Genome Analysis Toolkit)

# Set input parameters
REF="$HOME/internship_projects/life-science/RB20/RB20_Genome.fasta"
INPUT_BAM="sorted_output.bam"
SAMPLE_ID="SRR27892070"

# 1. Create a Sequence Dictionary for the Reference Genome
# GATK requires a .dict file alongside the .fasta reference
gatk CreateSequenceDictionary -R $REF

# 2. Add Read Groups to the BAM File
# GATK strictly requires Read Group (@RG) metadata (ID, Library, Platform, Sample)
gatk AddOrReplaceReadGroups \
  -I $INPUT_BAM \
  -O rg_sorted_output.bam \
  -RGID $SAMPLE_ID \
  -RGLB lib1 \
  -RGPL ILLUMINA \
  -RGPU unit1 \
  -RGSM $SAMPLE_ID

# 3. Mark PCR Duplicates
# Identifies and flags artifactual duplicate reads generated during library preparation
gatk MarkDuplicates \
  -I rg_sorted_output.bam \
  -O dedup_output.bam \
  -M marked_dup_metrics.txt

# 4. Index the Final Processed BAM File
samtools index dedup_output.bam

# 5. Execute Variant Discovery with GATK HaplotypeCaller
# Re-assembles local haplotypes to accurately call SNPs and Indels
gatk HaplotypeCaller \
  -R $REF \
  -I dedup_output.bam \
  -O gatk_raw_variants.vcf

# 6. Separate SNPs and Indels for Downstream Filtering
gatk SelectVariants \
  -R $REF \
  -V gatk_raw_variants.vcf \
  -select-type SNP \
  -O gatk_snps.vcf

gatk SelectVariants \
  -R $REF \
  -V gatk_raw_variants.vcf \
  -select-type INDEL \
  -O gatk_indels.vcf

# 7. Apply Hard Filters for Quality Control
# Filter SNPs based on Quality-by-Depth (QD) and Strand Bias (FS)
gatk VariantFiltration \
  -R $REF \
  -V gatk_snps.vcf \
  -O gatk_filtered_snps.vcf \
  --filter-name "QDFilter" --filter-expression "QD < 2.0" \
  --filter-name "FSFilter" --filter-expression "FS > 60.0" \
  --filter-name "MQFilter" --filter-expression "MQ < 40.0"
