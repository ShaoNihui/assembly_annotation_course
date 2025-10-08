#!/usr/bin/env bash
#SBATCH --cpus-per-task=4
#SBATCH --mem=40G
#SBATCH --time=04:00:00
#SBATCH --job-name=kmer
#SBATCH --mail-user=nihui.shao@students.unibe.ch
#SBATCH --mail-type=begin,end
#SBATCH --output=/data/users/nshao/assembly_annotation_course/scripts/kmer_%j.o
#SBATCH --error=/data/users/nshao/assembly_annotation_course/scripts/kmer_%j.e
#SBATCH --partition=pibu_el8

set -euo pipefail

WORKDIR=/data/users/nshao/assembly_annotation_course
OUT=$WORKDIR/read_QC/kmer_counting
mkdir -p "$OUT"

module load Jellyfish/2.3.0
K=21
THREADS=4

# 计数 k-mer（N13 数据）
jellyfish count -m $K -s 5G -t $THREADS -C \
  <(zcat $WORKDIR/N13/*.fastq.gz) \
  -o $OUT/reads_k$K.jf

# 生成直方图
jellyfish histo -t $THREADS $OUT/reads_k$K.jf > $OUT/reads_k$K.histo