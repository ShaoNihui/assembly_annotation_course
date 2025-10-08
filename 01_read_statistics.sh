#!/usr/bin/env bash
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --job-name=fastqc
#SBATCH --mail-user=nihui.shao@students.unibe.ch
#SBATCH --mail-type=begin,end
#SBATCH --output=/data/users/nshao/assembly_annotation_course/scripts/fastqc_%j.o
#SBATCH --error=/data/users/nshao/assembly_annotation_course/scripts/fastqc_%j.e
#SBATCH --partition=pibu_el8

set -euo pipefail

WORKDIR=/data/users/nshao/assembly_annotation_course
OUT=$WORKDIR/read_QC/fastqc
mkdir -p "$OUT"

module load FastQC/0.11.9-Java-11

fastqc -o "$OUT" -t 4 \
  $WORKDIR/N13/*.fastq.gz \
  $WORKDIR/RNAseq_Sha/*.fastq.gz