#!/usr/bin/env bash
#SBATCH --time=04:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8
#SBATCH --mail-user=nihui.shao@students.unibe.ch
#SBATCH --mail-type=begin,end
#SBATCH --job-name=quast
#SBATCH --output=/data/users/nshao/assembly_annotation_course/scripts/quast_%j.o
#SBATCH --error=/data/users/nshao/assembly_annotation_course/scripts/quast_%j.e
#SBATCH --partition=pibu_el8
set -euo pipefail

# ===== 基本路径 =====
WORKDIR=/data/users/nshao/assembly_annotation_course
OUTBASE=$WORKDIR/evaluations/quast
CONTAINER=/containers/apptainer/quast_5.2.0.sif
mkdir -p "$OUTBASE"

# ===== 你的装配（基因组）=====
FLYE=$WORKDIR/assemblies/flye/assembly.fasta
HIFI=$WORKDIR/assemblies/hifiasm/hifiasm.asm.bp.p_ctg.fa
LJA=$WORKDIR/assemblies/lja/assembly.fasta

# ===== 收集存在的装配 + 动态 labels =====
ASSEMS=()
LABELS=()

add_if_exists () {
  local fp="$1"
  local lb="$2"
  if [[ -s "$fp" ]]; then
    ASSEMS+=("$fp"); LABELS+=("$lb")
  else
    echo "[WARN] missing or empty: $fp (skip $lb)" >&2
  fi
}

add_if_exists "$FLYE" flye
add_if_exists "$HIFI" hifiasm
add_if_exists "$LJA"  lja

if [[ ${#ASSEMS[@]} -eq 0 ]]; then
  echo "[ERROR] No genome assemblies found for QUAST"; exit 1
fi

LABELS_CSV=$(IFS=,; echo "${LABELS[*]}")
THREADS=${SLURM_CPUS_PER_TASK:-8}

# ===== QUAST（无参考）=====
# 避免已有目录冲突：给结果目录加时间戳
OUTRUN="$OUTBASE/noref_$(date +%Y%m%d_%H%M%S)"
echo "[INFO] Running QUAST (no reference) for labels: $LABELS_CSV"
echo "[INFO] Output dir: $OUTRUN"

apptainer exec --bind "$WORKDIR" "$CONTAINER" \
  quast.py \
    --eukaryote \
    --threads "$THREADS" \
    --labels "$LABELS_CSV" \
    -o "$OUTRUN" \
    "${ASSEMS[@]}"

echo "[INFO] QUAST outputs: $OUTRUN"