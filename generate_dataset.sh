# run this to generate a dataset in one step.

echo "usage: ./generate_dataset SEED N_IMAGES(200 by default)"
python generate_vascu_config.py $1 $2 &&
./split_and_run.sh $1

