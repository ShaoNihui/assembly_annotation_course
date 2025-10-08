#!/usr/bin/env bash
#SBATCH --time=1-00:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=16
#SBATCH --job-name=flye
#SBATCH --mail-user=nihui.shao@students.unibe.ch
#SBATCH --mail-type=begin,end
#SBATCH --output=/data/users/nshao/assembly_annotation_course/scripts/flye_%j.o
#SBATCH --error=/data/users/nshao/assembly_annotation_course/scripts/flye_%j.e
#SBATCH --partition=pibu_el8

set -euo pipefail

WORKDIR=/data/users/nshao/assembly_annotation_course
OUT=$WORKDIR/assemblies/flye
mkdir -p "$OUT"

apptainer exec \
  --bind "$WORKDIR,/data/courses" \
  /containers/apptainer/flye_2.9.5.sif \
  flye \
  --pacbio-hifi "$WORKDIR"/N13/*.fastq.gz \
  --out-dir "$OUT" \
  --threads 16