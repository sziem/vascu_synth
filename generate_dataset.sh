# run this to generate a dataset in one step.

echo "usage: ./generate_dataset SEED N_IMAGES(200 by default)" &&
echo "seed"$1;
echo "seed"$1>seed.txt &&
python python_scripts/generate_vascu_config.py $1 $2 &&
./run_split/split_and_run.sh $1

