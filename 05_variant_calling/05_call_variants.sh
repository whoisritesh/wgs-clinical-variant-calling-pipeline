#!/bin/bash
# Step 5: Multi-threaded Variant Calling, VCF extraction, and statistics report

# 1. Pileup & Call Variants (for Haploid Organisms using 32 threads)
bcftools mpileup --threads 32 -f ~/internship_projects/life-science/RB20/RB20_Genome.fasta sorted_output.bam | \
bcftools call --threads 32 --ploidy 1 -mv -Ob -o variants.bcf

# 2. Convert BCF file to readable VCF format
bcftools view variants.bcf > final_variants.vcf

# 3. Output Variant Stats and inspect SNP summary metrics
bcftools stats variants.bcf > variant_stats.txt
cat variant_stats.txt | grep -A 10 "SNPs"
