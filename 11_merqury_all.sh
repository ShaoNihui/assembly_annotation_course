#!/usr/bin/env bash
#SBATCH --job-name=merqury_per_asm
#SBATCH --partition=pibu_el8
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=1-00:00:00
#SBATCH --mail-user=nihui.shao@students.unibe.ch
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --output=/data/users/nshao/assembly_annotation_course/evaluations/logs/%x-%j.out
#SBATCH --error=/data/users/nshao/assembly_annotation_course/evaluations/logs/%x-%j.err
#SBATCH --chdir=/data/usersqueue -u nshaos/nshao/assembly_annotation_course

# ==== 仅以下变量按你环境改过，其它逻辑保持不变 ====

# 你的工作目录
WORKDIR=/data/users/nshao/assembly_annotation_course

# HiFi reads：课程数据在项目根目录的软链 N13
# （保持和你之前用的一致；如果有多个文件，会自动展开）
READS=$WORKDIR/N13/*.fastq.gz

# 输出目录与容器
OUTDIR=$WORKDIR/evaluations/merqury
CONTAINER_PATH="/containers/apptainer/merqury_1.3.sif"

mkdir -p "$OUTDIR" "$WORKDIR/evaluations/logs"

# 三个 genome assemblies 的实际位置（与你之前的路径一致）
FLYE=$WORKDIR/assemblies/flye/assembly.fasta
HIFIASM=$WORKDIR/assemblies/hifiasm/hifiasm.asm.bp.p_ctg.fa
LJA=$WORKDIR/assemblies/lja/assembly.fasta

# 容器里的 Merqury 安装目录
export MERQURY="/usr/local/share/merqury"

# ===== 1) 用 HiFi reads 构建 meryl 数据库（若已存在则复用）=====
if [ ! -d "$OUTDIR/hifi.meryl" ]; then
  echo "[INFO] Building meryl DB from reads -> $OUTDIR/hifi.meryl"
  apptainer exec --bind /data "$CONTAINER_PATH" \
    meryl count k=21 output "$OUTDIR/hifi.meryl" $READS
else
  echo "[INFO] Using existing meryl DB: $OUTDIR/hifi.meryl"
fi

# ===== 2) 逐个 assembly 跑 Merqury =====
for ASM in flye hifiasm lja; do
  echo "[INFO] Running Merqury for $ASM ..."
  mkdir -p "$OUTDIR/$ASM"
  cd "$OUTDIR/$ASM"

  if [ "$ASM" == "flye" ]; then
    ASMFILE="$FLYE"
  elif [ "$ASM" == "hifiasm" ]; then
    ASMFILE="$HIFIASM"
  else
    ASMFILE="$LJA"
  fi

  apptainer exec --bind /data "$CONTAINER_PATH" \
    "$MERQURY/merqury.sh" "$OUTDIR/hifi.meryl" "$ASMFILE" "$ASM"
done