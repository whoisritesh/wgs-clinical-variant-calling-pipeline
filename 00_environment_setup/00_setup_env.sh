#!/bin/bash
# Step 0: Add local tool directories to master PATH permanently inside ~/.bashrc

echo 'export PATH="$HOME/internship_projects/life-science/sratoolkit.3.4.1-ubuntu64/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/internship_projects/life-science/FastQC:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/internship_projects/life-science/bwa:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/internship_projects/life-science/samtools:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/internship_projects/life-science/bcftools:$PATH"' >> ~/.bashrc

# Setup Trimmomatic alias
echo 'alias trimmomatic="java -jar $HOME/internship_projects/life-science/trimmomatic-0.40.jar"' >> ~/.bashrc

# Reload bash profile configurations
source ~/.bashrc
