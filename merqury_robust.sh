#!/usr/bin/env bash
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --partition=pibu_el8
#SBATCH --job-name=merqury_robust
#SBATCH --mail-user=nihui.shao@students.unibe.ch
#SBATCH --mail-type=END,FAIL
#SBATCH --output=/data/users/nshao/assembly_annotation_course/scripts/merqury_robust_%j.o
#SBATCH --error=/data/users/nshao/assembly_annotation_course/scripts/merqury_robust_%j.e

set -euo pipefail

WORKDIR=/data/users/nshao/assembly_annotation_course
OUTDIR=$WORKDIR/evaluations/merqury
READS_DIR=$WORKDIR/N13
CONTAINER=/containers/apptainer/merqury_1.3.sif
export MERQURY=/usr/local/share/merqury
K=31
THREADS=${SLURM_CPUS_PER_TASK:-8}
CLEAN_HEADERS=${CLEAN_HEADERS:-true}

mkdir -p "$OUTDIR"

# 统一用 bash -lc，确保支持进程替代 <(...) 与通配展开
run() { local wd=$1; shift; apptainer exec --bind /data/users/nshao --pwd "$wd" "$CONTAINER" "$@"; }

# 验证 meryl DB，有问题则重建
validate_or_rebuild() {
  local dbdir=$1
  local build_cmd=$2   # 这里传入“整段命令字符串”，在 bash -lc 里跑
  if [[ -d "$dbdir" ]]; then
    if run "$(dirname "$dbdir")" bash -lc "meryl statistics '$dbdir' >/dev/null 2>&1"; then
      echo "[INFO] Valid meryl DB found: $dbdir"
      return 0
    else
      echo "[WARN] Corrupted/incomplete meryl DB detected, rebuilding: $dbdir"
      rm -rf "$dbdir"
    fi
  fi
  echo "[INFO] Building meryl DB: $dbdir"
  run "$(dirname "$dbdir")" bash -lc "$build_cmd"
}

echo "======= Merqury robust (k=$K) ======="
echo "[STEP 1] Counting k-mers from reads"

# 收集 reads
shopt -s nullglob
READS=( "$READS_DIR"/*.fastq.gz "$READS_DIR"/*.fq.gz "$READS_DIR"/*.fastq "$READS_DIR"/*.fq )
shopt -u nullglob
(( ${#READS[@]} > 0 )) || { echo "[ERROR] No reads in $READS_DIR"; exit 1; }

READS_DB="$OUTDIR/N13.k${K}.meryl"

# 组装“支持 .gz 的 meryl count 命令”：.gz 用 <(zcat ...)，非压缩直接用路径
build_reads_cmd() {
  local cmd="meryl count k=$K threads=$THREADS"
  for f in "${READS[@]}"; do
    if [[ "$f" == *.gz ]]; then
      cmd+=" <(zcat '$f')"
    else
      cmd+=" '$f'"
    fi
  done
  cmd+=" output '$READS_DB'"
  printf '%s' "$cmd"
}

READS_CMD="$(build_reads_cmd)"
validate_or_rebuild "$READS_DB" "$READS_CMD"

# 统计与直方图
run "$OUTDIR" bash -lc "meryl statistics '$READS_DB' > stats_reads.txt"
sed -n '1,10p' "$OUTDIR/stats_reads.txt" || true

if [[ ! -s "$OUTDIR/N13.k${K}.hist" ]]; then
  run "$OUTDIR" bash -lc "meryl histogram '$READS_DB' > N13.k${K}.hist"
  run "$OUTDIR" java -jar "$MERQURY/eval/kmerHistToPloidyDepth.jar" "$OUTDIR/N13.k${K}.hist" || true
fi

# 装配列表
declare -A ASMFA=(
  [flye]="$WORKDIR/assemblies/flye/assembly.fasta"
  [hifiasm]="$WORKDIR/assemblies/hifiasm/hifiasm.asm.bp.p_ctg.fa"
  [lja]="$WORKDIR/assemblies/lja/assembly.fasta"
)

# 为每个装配建 meryl DB
build_asm_meryl () {
  local tag=$1 asm=$2 work=$OUTDIR/$tag
  mkdir -p "$work"
  [[ -s "$asm" ]] || { echo "[WARN] $tag missing: $asm"; return 0; }

  cp -f "$asm" "$work/${tag}.fasta"
  if [[ "$CLEAN_HEADERS" == "true" ]]; then
    cp -f "$work/${tag}.fasta" "$work/${tag}.fasta.bak"
    awk '/^>/{sub(/^>/,">"); gsub(/ .*/,""); print; next} {print toupper($0)}' \
      "$work/${tag}.fasta.bak" > "$work/${tag}.fasta"
  fi

  local ASM_DB="$work/${tag}.0.meryl"
  local CMD="meryl count k=$K threads=$THREADS '${tag}.fasta' output '${tag}.0.meryl'"
  validate_or_rebuild "$ASM_DB" "$CMD"

  run "$work" bash -lc "meryl statistics '${tag}.0.meryl' > stats_asm.txt"
  sed -n '1,10p' "$work/stats_asm.txt" || true

  ln -sf "$READS_DB" "$work/$(basename "$READS_DB")"
  ln -sf "$OUTDIR/N13.k${K}.hist" "$work/N13.k${K}.hist"
}

echo "[STEP 2] Build meryl DBs for assemblies"
for tag in flye hifiasm lja; do build_asm_meryl "$tag" "${ASMFA[$tag]}"; done

# 运行 merqury.sh
run_merqury () {
  local tag=$1 work=$OUTDIR/$tag
  [[ -d "$work/${tag}.0.meryl" ]] || { echo "[WARN] skip $tag"; return; }
  echo "[STEP 3] merqury: $tag"
  run "$work" bash -lc "'$MERQURY/merqury.sh' 'N13.k${K}.meryl' '${tag}.fasta' '$tag'"
}

for tag in flye hifiasm lja; do run_merqury "$tag"; done

echo "[DONE] outputs -> $OUTDIR"
echo "  - *.qv, *.completeness.stats, spectra-*.png"