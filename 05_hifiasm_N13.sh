#!/usr/bin/env bash
#SBATCH --time=1-00:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=16
#SBATCH --job-name=hifiasm
#SBATCH --mail-user=nihui.shao@students.unibe.ch
#SBATCH --mail-type=begin,end
#SBATCH --output=/data/users/nshao/assembly_annotation_course/scripts/hifiasm_%j.o
#SBATCH --error=/data/users/nshao/assembly_annotation_course/scripts/hifiasm_%j.e
#SBATCH --partition=pibu_el8

set -euo pipefail

WORKDIR=/data/users/nshao/assembly_annotation_course
READS_DIR=$WORKDIR/N13
OUTDIR=$WORKDIR/assemblies/hifiasm
PREFIX=$OUTDIR/hifiasm.asm
THREADS=16

mkdir -p "$OUTDIR"

# 收集 HiFi 读段（支持单个或多个）
READS=( "$READS_DIR"/*.fastq.gz )
if [[ ! -e "${READS[0]}" ]]; then
  echo "[ERROR] No HiFi fastq.gz found in $READS_DIR" >&2
  exit 1
fi

# 绑定你的工作区 + 课程数据根，避免容器内路径不可见
apptainer exec \
  --bind "$WORKDIR,/data/courses/assembly-annotation-course" \
  /containers/apptainer/hifiasm_0.25.0.sif \
  hifiasm \
    -o "$PREFIX" \
    -t "$THREADS" \
    -f0 \
    "${READS[@]}"
    # 如样本极近交/同质，可尝试去掉去重： -l0
    # 旧HiFi端修剪可加： -z20
    # 需要导出纠错reads/PAF可加： --write-ec --write-paf

# 将所有 p_ctg.gfa 转换为 fasta（primary + hap1 + hap2 若存在）
for gfa in "$OUTDIR"/*.p_ctg.gfa "$OUTDIR"/*.bp.p_ctg.gfa; do
  [[ -e "$gfa" ]] || continue
  fa="${gfa%.gfa}.fa"
  awk '/^S/{print ">"$2;print $3}' "$gfa" > "$fa"
  echo "[INFO] GFA -> FASTA: $(basename "$gfa") -> $(basename "$fa")"
done

echo "[INFO] Done. Outputs in $OUTDIR:"
ls -lh "$OUTDIR" | sed 's/^/[INFO] /'