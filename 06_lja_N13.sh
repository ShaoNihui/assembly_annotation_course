#!/usr/bin/env bash
#SBATCH --time=1-00:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=16
#SBATCH --job-name=lja
#SBATCH --mail-user=nihui.shao@students.unibe.ch
#SBATCH --mail-type=begin,end
#SBATCH --output=/data/users/nshao/assembly_annotation_course/scripts/lja_%j.o
#SBATCH --error=/data/users/nshao/assembly_annotation_course/scripts/lja_%j.e
#SBATCH --partition=pibu_el8

set -euo pipefail
shopt -s nullglob

WORKDIR=/data/users/nshao/assembly_annotation_course
OUT=$WORKDIR/assemblies/lja
mkdir -p "$OUT"

# 收集 HiFi 读段（支持 .fastq.gz 和 .fastq）
READS=( "$WORKDIR/N13"/*.fastq.gz "$WORKDIR/N13"/*.fastq )
if (( ${#READS[@]} == 0 )); then
  echo "[ERROR] No HiFi FASTQ found under $WORKDIR/N13" >&2
  exit 2
fi

# 为 LJA 构建 --reads 参数列表（每个文件一个 --reads）
ARGS=()
for f in "${READS[@]}"; do
  ARGS+=( --reads "$f" )
done

# 运行 LJA：注意 -o/--output-dir，且绑定课程目录以支持软链
apptainer exec \
  --bind "$WORKDIR,/data/courses" \
  /containers/apptainer/lja-0.2.sif \
  lja \
    -o "$OUT" \
    --threads 16 \
    "${ARGS[@]}"