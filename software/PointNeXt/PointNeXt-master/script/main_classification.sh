#!/usr/bin/env bash
#SBATCH -N 1
#SBATCH --array=0-1
#SBATCH -J modelnet
#SBATCH -o slurm_logs/%x.%3a.%A.out
#SBATCH -e slurm_logs/%x.%3a.%A.err
#SBATCH --time=6:00:00
#SBATCH --gres=gpu:1
#SBATCH --constraint=[v100]
#SBATCH --cpus-per-gpu=6
#SBATCH --mem=30G
##SBATCH --mail-type=FAIL,TIME_LIMIT,TIME_LIMIT_90

module load cuda/11.1.1
module load gcc
echo "===> Anaconda env loaded"
# source activate openpoints
source activate /opt/conda/envs/openpoints

while true
do
    PORT=$(( ((RANDOM<<15)|RANDOM) % 49152 + 10000 ))
    status="$(nc -z 127.0.0.1 $PORT < /dev/null &>/dev/null; echo $?)"
    if [ "${status}" != "0" ]; then
        break;
    fi
done
echo $PORT

nvidia-smi
nvcc --version

hostname
NUM_GPU_AVAILABLE=`nvidia-smi --query-gpu=name --format=csv,noheader | wc -l`
echo $NUM_GPU_AVAILABLE


cfg=$1
PY_ARGS=${@:2}
python examples/classification/main.py --cfg $cfg  wandb.use_wandb=False ${PY_ARGS}

# how to run
# this script supports training using 1 GPU or multi-gpu,
# simply run jobs on multiple GPUs will launch distributed training by default.
# load different cfgs for training on different benchmarks (modelnet40 classification, or scanobjectnn classification) and using different models.

# For examples,
# if using a cluster with slurm, train PointNeXt-S on scanobjectnn classification using only 1 GPU, by 3 times:
# sbatch --array=0-2 --gres=gpu:1 --time=10:00:00 main_classification.sh cfgs/scaobjetnn/pointnext-s.yaml

# if using local machine with GPUs, train PointNeXt-S on scanobjectnn classification using all GPUs
# bash script/main_classification.sh cfgs/scaobjetnn/pointnext-s.yaml

# if using local machine with GPUs, train PointNeXt-S on scanobjectnn classification using only 1 GPU
# CUDA_VISIBLE_DEVICES=1 bash script/main_classification.sh cfgs/scaobjetnn/pointnext-s.yaml
