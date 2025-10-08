#!/usr/bin/env bash
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --job-name=fastp
#SBATCH --mail-user=nihui.shao@students.unibe.ch
#SBATCH --mail-type=end
#SBATCH --output=/data/users/nshao/assembly_annotation_course/scripts/fastp_%j.o
#SBATCH --error=/data/users/nshao/assembly_annotation_course/scripts/fastp_%j.e
#SBATCH --partition=pibu_el8

set -euo pipefail

WORKDIR=/data/users/nshao/assembly_annotation_course
RNA=$WORKDIR/RNAseq_Sha            # 只读软链（输入）
OUT=$WORKDIR/read_QC/fastp         # 可写目录（输出）
mkdir -p "$OUT"

module load fastp/0.23.4

# 1) RNA-seq 过滤 & 修剪（输出到可写目录 OUT）
fastp \
  -i  "$RNA/ERR754081_1.fastq.gz" \
  -I  "$RNA/ERR754081_2.fastq.gz" \
  -o  "$OUT/ERR754081_1.clean.fastq.gz" \
  -O  "$OUT/ERR754081_2.clean.fastq.gz" \
  -h  "$OUT/fastp_RNAseq.html" \
  -j  "$OUT/fastp_RNAseq.json" \
  -q 20 -u 30 -l 50 -w 4

# 2) PacBio HiFi：不做过滤，仅生成统计报告
# fastp 单次只能处理一对/一个输入，这里对 N13 目录下每个 fastq.gz 循环跑一次
for f in "$WORKDIR/N13"/*.fastq.gz; do
  bn=$(basename "$f" .fastq.gz)
  fastp \
    -i "$f" \
    -o /dev/null \
    -h "$OUT/fastp_HiFi_${bn}.html" \
    -j "$OUT/fastp_HiFi_${bn}.json" \
    --thread 4 \
    --disable_quality_filtering \
    --disable_length_filtering \
    --disable_adapter_trimming
done