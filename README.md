Recommended pipeline for dataset generation:


1. change seed (and possibly other parameters) in generate_vascu_config.py
2. run generate_vascu_config.py
3. run split_and_run.sh
4. wait for run split_and_run.sh to finish
5. rename CHANGE_NAME-folder, eg. to the number of the random seed used

6. run matlab_scripts/create_simulated_data_pairs.m to generate pairs of ground truth samples (obj) and simulated microscopic images (img)

7. to create the h5 dataset that can be input to unet, run generate_h5.py from unet_deconv repository on the data pairs