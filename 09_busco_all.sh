#!/usr/bin/env bash
#SBATCH --time=06:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8
#SBATCH --job-name=busco_all
#SBATCH --mail-user=nihui.shao@students.unibe.ch
#SBATCH --mail-type=begin,end
#SBATCH --output=/data/users/nshao/assembly_annotation_course/scripts/busco_%j.o
#SBATCH --error=/data/users/nshao/assembly_annotation_course/scripts/busco_%j.e
#SBATCH --partition=pibu_el8

set -euo pipefail

# ===== 基本路径 =====
WORKDIR=/data/users/nshao/assembly_annotation_course
OUTDIR=$WORKDIR/evaluations/busco
CONTAINER=/containers/apptainer/busco_5.7.1.sif
mkdir -p "$OUTDIR"

# ===== 你的装配 =====
FLYE=$WORKDIR/assemblies/flye/assembly.fasta
LJA=$WORKDIR/assemblies/lja/assembly.fasta
HIFI_PRIMARY=$WORKDIR/assemblies/hifiasm/hifiasm.asm.bp.p_ctg.fa
HIFI_HAP1=$WORKDIR/assemblies/hifiasm/hifiasm.asm.bp.hap1.p_ctg.fa
HIFI_HAP2=$WORKDIR/assemblies/hifiasm/hifiasm.asm.bp.hap2.p_ctg.fa
TRINITY=$WORKDIR/assemblies/Trinity.Trinity.fasta

# ===== 直接使用 lineage 绝对路径（离线，不用下载/拷贝）=====
LINEAGE_PATH=/data/databases/busco5/busco_database/lineages/brassicales_odb10
if [[ ! -d "$LINEAGE_PATH" ]]; then
  echo "[ERROR] Lineage path not found: $LINEAGE_PATH" >&2
  exit 2
fi

# 覆盖策略：如果结果目录存在，BUSCO 默认会报错退出。
# 我们统一加 -f 允许覆盖；如不想覆盖，将 FORCE=0
FORCE=${FORCE:-1}
BUSCO_FORCE_FLAG=()
if [[ "$FORCE" == "1" ]]; then
  BUSCO_FORCE_FLAG=(-f)
fi

run_busco () {
  local input=$1   # fasta
  local mode=$2    # genome | transcriptome
  local name=$3    # 输出目录名（相对 OUTDIR）
  echo "[INFO] BUSCO: $name  mode=$mode"
  if [[ ! -s "$input" ]]; then
    echo "[WARN] 路径不存在或为空：$input，跳过 $name" >&2
    return 0
  fi

  # 运行 BUSCO（绑定 /data 以访问 lineage 绝对路径）
  apptainer exec \
    --bind "/data,$WORKDIR" \
    "$CONTAINER" \
    busco \
      -i "$input" \
      -m "$mode" \
      -l "$LINEAGE_PATH" \
      -c "${SLURM_CPUS_PER_TASK:-8}" \
      -o "$name" \
      --out_path "$OUTDIR" \
      --offline \
      "${BUSCO_FORCE_FLAG[@]}"
}

# ===== 逐个运行 =====
run_busco "$FLYE"         genome        flye_busco
run_busco "$LJA"          genome        lja_busco
run_busco "$HIFI_PRIMARY" genome        hifiasm_primary_busco
run_busco "$HIFI_HAP1"    genome        hifiasm_hap1_busco
run_busco "$HIFI_HAP2"    genome        hifiasm_hap2_busco
run_busco "$TRINITY"      transcriptome trinity_busco

echo "[DONE] BUSCO 完成。输出目录：$OUTDIR"