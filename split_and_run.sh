# generate_vascu_config.py SEED #TODO make function that takes seed

# this should include 
mkdir CHANGE_NAME &
mv *.txt CHANGE_NAME &  # TODO: make arg to shell function
# this should include image_params.txt, image_names.txt, supply.txt, all demands and all param files
cp VascuSynthPng CHANGE_NAME &  # TODO: change so that I don't need several copies of it
split_and_run.sh &
echo dataset created in folder CHANGE_NAME.
