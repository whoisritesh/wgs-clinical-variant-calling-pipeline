#!/bin/bash
# Step 4: SAM-to-BAM sorting, indexing, and alignment mapping stats

# 1. Sort SAM output into binary coordinate-sorted BAM (32 threads)
samtools sort -@ 32 -o sorted_output.bam output.sam

# 2. Index the BAM alignment file
samtools index sorted_output.bam

# 3. Output flagstat mapping quality report
samtools flagstat sorted_output.bam > alignment_stats.txt
