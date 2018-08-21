# change SEED in generate vascu_config.py first and run it

# TODO allow to run this as python 
# generate_vascu_config.py SEED #TODO make function that takes seed

# Do not change as CHANGE_NAME is hardcoded into split_vascu_config.py
CHANGE_NAME=CHANGE_NAME &&

# this should include 
mkdir -p $CHANGE_NAME &&
mv *.txt $CHANGE_NAME;  # TODO: make arg to shell function
# this should include image_params.txt, image_names.txt, supply.txt, all demands and all param files

cp run_sequential_*.sh $CHANGE_NAME &&
cp VascuSynthPng $CHANGE_NAME &&  # TODO: change so that I don't need several copies of it
python split_vascu_config.py &&
cp *.txt $CHANGE_NAME;  # not sure this is necessary here
cd $CHANGE_NAME &&

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

