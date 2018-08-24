# Instructions:
# The easiest way to generate objects is to use ./generate_dataset.sh SEED N_IMAGES

# First run python generate_vascu_config.py SEED N_IMAGES

# You may change the name of the folder it is saved in by calling ./split_and_run FOLDER_NAME
FOLDER_NAME="seed"$1
if [ -z "$FOLDER_NAME" ]; then
        FOLDER_NAME=CHANGE_NAME;
   fi

mkdir -p $FOLDER_NAME/original_data &&
mv *.txt $FOLDER_NAME/original_data; # this should include image_params.txt, image_names.txt, supply.txt, all demands and all param files
cp run_sequential_*.sh $FOLDER_NAME/original_data &&
cp VascuSynthPng $FOLDER_NAME/original_data &&  # TODO: change so that I don't need several copies of it
python split_vascu_config.py $FOLDER_NAME &&
cp *.txt $FOLDER_NAME/original_data;  # copy the image_names_split etc. files
cd $FOLDER_NAME/original_data && 

screen -dmS "vascu1" &&
screen -dmS "vascu2" &&
screen -dmS "vascu3" &&
screen -dmS "vascu4" &&
screen -dmS "vascu5" &&

screen -S "vascu1" -p 0 -X stuff "./run_sequential_1.sh && exit\n" &&
screen -S "vascu2" -p 0 -X stuff "./run_sequential_2.sh && exit\n" &&
screen -S "vascu3" -p 0 -X stuff "./run_sequential_3.sh && exit\n" &&
screen -S "vascu4" -p 0 -X stuff "./run_sequential_4.sh && exit\n" &&
screen -S "vascu5" -p 0 -X stuff "./run_sequential_5.sh && exit\n" &&

echo "running vascu synth in screens vascu1, vascu2, vascu3, vascu4, vascu5" &&
screen -ls;

