#!/usr/bin/env bash
#SBATCH --time=08:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --partition=pibu_el8
#SBATCH --job-name=nucmer_mummerplot
#SBATCH --mail-user=nihui.shao@students.unibe.ch
#SBATCH --mail-type=begin,end,fail
#SBATCH --output=/data/users/nshao/assembly_annotation_course/scripts/11_nucmer_mummerplot_%j.o
#SBATCH --error=/data/users/nshao/assembly_annotation_course/scripts/11_nucmer_mummerplot_%j.e

set -euo pipefail

# ========= 基本路径 =========
WORKDIR=/data/users/nshao/assembly_annotation_course
OUTBASE=$WORKDIR/evaluations/mummer
CONTAINER=/containers/apptainer/mummer4_gnuplot.sif
mkdir -p "$OUTBASE"

# ========= 参考基因组（直接用课程提供的路径）=========
REF_FA=/data/courses/assembly-annotation-course/references/Arabidopsis_thaliana.TAIR10.dna.toplevel.fa

# ========= 三个装配 =========
FLYE=$WORKDIR/assemblies/flye/assembly.fasta
HIFIP=$WORKDIR/assemblies/hifiasm/hifiasm.asm.bp.p_ctg.fa
LJA=$WORKDIR/assemblies/lja/assembly.fasta

# ========= 输出目录 =========
VS_REF=$OUTBASE/vs_ref
VS_EACH=$OUTBASE/vs_each
mkdir -p "$VS_REF" "$VS_EACH"

# ========= 资源 =========
THREADS=${SLURM_CPUS_PER_TASK:-8}

# ========= 便捷执行（绑定 /data/users 与 /data/courses）=========
run() {
  local wd=$1; shift
  apptainer exec --bind /data/users,/data/courses --pwd "$wd" "$CONTAINER" "$@"
}

# ========= 自检 =========
need() {
  local f=$1
  if [[ ! -s "$f" ]]; then
    echo "[ERROR] missing or empty: $f" >&2
    exit 1
  fi
}
need "$REF_FA"
need "$FLYE"
need "$HIFIP"
need "$LJA"

# ========= 1) 装配 vs 参考 =========
align_vs_ref() {
  local asm=$1
  local tag=$2
  local outdir=$VS_REF/$tag
  mkdir -p "$outdir"
  echo "[INFO] vs_ref: $tag"

  # 1. 比对
  run "$outdir" nucmer \
    --threads="$THREADS" \
    --breaklen 1000 \
    --mincluster 1000 \
    --prefix "${tag}_vs_ref" \
    "$REF_FA" "$asm"

  # 2. 坐标表
  run "$outdir" show-coords -rTlH "${tag}_vs_ref.delta" > "${tag}_vs_ref.coords.txt"

  # 3. dotplot（PNG）
  run "$outdir" mummerplot \
    -R "$REF_FA" \
    -Q "$asm" \
    --filter \
    -t png \
    --large \
    --layout \
    --fat \
    -p "${tag}_vs_ref" \
    "${tag}_vs_ref.delta"

  echo "[OK] vs_ref done: $outdir/${tag}_vs_ref.png"
}

align_vs_ref "$FLYE"  flye
align_vs_ref "$HIFIP" hifiasm
align_vs_ref "$LJA"   lja

# ========= 2) 装配两两互比 =========
pairwise() {
  local faA=$1; local tagA=$2
  local faB=$3; local tagB=$4

  local outdir=$VS_EACH/${tagA}_vs_${tagB}
  mkdir -p "$outdir"
  echo "[INFO] pairwise: ${tagA} vs ${tagB}"

  # A 作参考，B 作查询
  run "$outdir" nucmer \
    --threads="$THREADS" \
    --breaklen 1000 \
    --mincluster 1000 \
    --prefix "${tagA}_vs_${tagB}" \
    "$faA" "$faB"

  run "$outdir" show-coords -rTlH "${tagA}_vs_${tagB}.delta" > "${tagA}_vs_${tagB}.coords.txt"

  run "$outdir" mummerplot \
    -R "$faA" \
    -Q "$faB" \
    --filter \
    -t png \
    --large \
    --layout \
    --fat \
    -p "${tagA}_vs_${tagB}" \
    "${tagA}_vs_${tagB}.delta"

  echo "[OK] pairwise done: $outdir/${tagA}_vs_${tagB}.png"
}

pairwise "$FLYE"  flye    "$HIFIP" hifiasm
pairwise "$FLYE"  flye    "$LJA"   lja
pairwise "$HIFIP" hifiasm "$LJA"   lja

echo
echo "[DONE] All dotplots:"
echo "  - vs_ref PNG:  $VS_REF/*/*.png"
echo "  - pairwise:    $VS_EACH/*/*.png"
echo "  - coords:      *.coords.txt （匹配坐标统计）"