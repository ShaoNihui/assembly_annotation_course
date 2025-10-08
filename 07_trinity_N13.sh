#!/usr/bin/env bash
#SBATCH --time=1-00:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=16
#SBATCH --job-name=trinity
#SBATCH --mail-user=nihui.shao@students.unibe.ch
#SBATCH --mail-type=begin,end
#SBATCH --output=/data/users/nshao/assembly_annotation_course/scripts/trinity_%j.o
#SBATCH --error=/data/users/nshao/assembly_annotation_course/scripts/trinity_%j.e
#SBATCH --partition=pibu_el8

set -euo pipefail

WORKDIR=/data/users/nshao/assembly_annotation_course
OUT=$WORKDIR/assemblies/Trinity
RNA=$WORKDIR/read_QC/fastp   # RNA-seq 清洗后的文件
mkdir -p "$OUT"

module load Trinity/2.15.1

Trinity \
  --seqType fq \
  --max_memory 60G \
  --left  $RNA/ERR754081_1.clean.fastq.gz \
  --right $RNA/ERR754081_2.clean.fastq.gz \
  --CPU 16 \
  --output $OUT