# Vascu Synth
Vascu Synth is a software for simulating 3D images of blood vessels.  They are produced as a series of png-images in a folder.  The images can be used, for example, as test images for 3D image analysis or to generate datasets for use in deep learning.  This repository contains a clone of the software together with installation instrucations and scripts that simplify usage.

## Attribution
I am not the author of the software.  Please refer to the following links for the official documentation.

Code was originally posted at  
https://github.com/midas-journal/midas-journal-794.  
The project website is 
http://vascusynth.cs.sfu.ca.  
The following research papers provide additional information:  
http://dx.doi.org/10.1016/j.compmedimag.2010.06.002  
http://dx.doi.org/10380/3260  

## Contents
'Sources' contains the vascu synth C++ sources cloned from the link above.  The only change made to them is to output png-images instead of jpg and to add an extra digit to the filenames to possibly allow stacks with more than 1000 images.

'example_config' contains example config files and a call that can be used for testing after compiling the sources.

The software used only a single CPU and slowly filled up our system's memory while running.  For cheap parallelization and as a workaround for the memory leak, generating a dataset was split into several calls to Vascu Synth.

'example_run_split' contains shell scripts that can be called from different terminals to generate a dataset of 200 images using 5 CPUs and clearing memory every 10 images on each CPU.

'matlab_scripts' contains matlab-scripts for generating a dataset that can be used for deconvolution.  This makes use of a number of toolboxes that may not be available on every system.  They include
* https://github.com/soezie/matlab_tools
* Toolboxes from our research group: https://nanoimaging.de/
* DipImage http://www.diplib.org/
Please contact us, if you are interested in using these scripts.

# Usage
## Prerequisites:
Assuming VascuSynth has been compiled successfully:

The shell scripts have been tested in bash.  Using the config generators called from the scripts requires Python (tested with Python 3.6) and some python-packages.  Objects can be generated with this.

The matlab-scripts require matlab and above named toolboxes.

## New recommended pipeline for object generation:
1. run ./generate_dataset.sh SEED N_IMAGES(200 by default)
--> continue with step 6 and 7 to use the matlab scripts

## Old pipeline for dataset generation:
1. change seed (and possibly other parameters) in generate_vascu_config.py
2. run generate_vascu_config.py
3. run split_and_run.sh
4. wait for run split_and_run.sh to finish
5. rename CHANGE_NAME-folder, eg. to the number of the random seed used
--> continue with step 6 and 7 to use the matlab scripts

## Using matlab Scripts
6. run matlab_scripts/create_simulated_data_pairs.m to generate pairs of ground truth samples (obj) and simulated microscopic images (img)
7. to create the h5 dataset that can be input to unet, run generate_h5.py from unet_deconv repository on the data pairs

# Compiling VascuSynth
Installation instruction can be found in  
http://dx.doi.org/10380/3260  

We were able to compile successfully with cmake-3.10 and Insight Toolkit (ITK) 4.13 (with compatibility to ITK 3 set in CMake), but there were some issues.  Particularly note the modified CMakeLists.txt.
