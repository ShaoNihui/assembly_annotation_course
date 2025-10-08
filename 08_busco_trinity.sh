#!/usr/bin/env bash
#SBATCH --time=06:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8
#SBATCH --job-name=busco_trinity
#SBATCH --mail-user=nihui.shao@students.unibe.ch
#SBATCH --mail-type=begin,end
#SBATCH --output=/data/users/nshao/assembly_annotation_course/scripts/busco_trinity_%j.o
#SBATCH --error=/data/users/nshao/assembly_annotation_course/scripts/busco_trinity_%j.e
#SBATCH --partition=pibu_el8

set -euo pipefail

# ===== 基本路径 =====
WORKDIR=/data/users/nshao/assembly_annotation_course
OUTDIR=$WORKDIR/evaluations/busco
CONTAINER=/containers/apptainer/busco_5.7.1.sif
mkdir -p "$OUTDIR"

# ===== Trinity 输出 fasta（注意命名规则）=====
TRINITY=$WORKDIR/assemblies/Trinity.Trinity.fasta

# ===== 直接使用你刚找到的 lineage 绝对路径（无需下载/拷贝）=====
LINEAGE_PATH=/data/databases/busco5/busco_database/lineages/brassicales_odb10

# ===== 自检 =====
echo "[INFO] BUSCO(trinity) using lineage path: $LINEAGE_PATH (OFFLINE mode)"
if [[ ! -s "$TRINITY" ]]; then
  echo "[ERROR] Trinity fasta not found or empty: $TRINITY" >&2
  exit 1
fi
if [[ ! -d "$LINEAGE_PATH" ]]; then
  echo "[ERROR] Lineage path not found: $LINEAGE_PATH" >&2
  exit 2
fi

# ===== 运行 BUSCO（transcriptome + offline）=====
# 绑定 /data，确保容器内也能访问 /data/databases/...
apptainer exec \
  --bind "/data,$WORKDIR" \
  --pwd "$OUTDIR" \
  "$CONTAINER" \
  busco \
    -i "$TRINITY" \
    -m transcriptome \
    -l "$LINEAGE_PATH" \
    -c "${SLURM_CPUS_PER_TASK:-8}" \
    -o trinity_busco \
    --out_path "$OUTDIR" \
    --offline

echo "[DONE] Trinity BUSCO 完成。结果在：$OUTDIR/trinity_busco"