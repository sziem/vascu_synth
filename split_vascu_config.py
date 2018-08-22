#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Aug  2 10:31:06 2018

@author: soenke
"""

import numpy as np
import os

"""
counteract memory leak of vascu_synth by using smaller image_lists and 
param_files.
"""

def split_vascu_params(vascu_path, image_names="image_names.txt", image_params="image_params.txt"):    
    names_list = _split_txt_into_subfiles(image_names, vascu_path, 10)
    param_list = _split_txt_into_subfiles(image_params, vascu_path, 10)

    np.savetxt(os.path.join(vascu_path, "image_params_all_splits"), param_list, fmt='%s')
    np.savetxt(os.path.join(vascu_path, "image_names_all_splits"), names_list, fmt='%s')
    
def _split_txt_into_subfiles(filename, filepath, lines_per_file):
    full_path = os.path.join(filepath, filename)

    smallfile = None
    file_list = list()
    with open(full_path) as bigfile:
        for lineno, line in enumerate(bigfile):
            if lineno % lines_per_file == 0:
                if smallfile:
                    smallfile.close()
                small_filename = os.path.join(filepath, filename[0:-4] + "_split{}.txt".format(lineno + lines_per_file))
                file_list.append(small_filename)
                smallfile = open(small_filename, "w")
            smallfile.write(line)
        if smallfile:
            smallfile.close()
    return file_list

def main():
    vascu_path = os.path.join("CHANGE_NAME","original_data")  # TODO: change
    split_vascu_params(vascu_path)

if __name__ == '__main__':
    main()    
