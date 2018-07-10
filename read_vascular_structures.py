#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Jul 10 15:59:02 2018

@author: soenke
"""

import numpy as np
import imageio
import glob
from os import path
import toolbox.view3d as view3d


ims = list()
def read_vascular_volume(impath):
    """read all png-files in impath and return them as np-array.
       Shape will be in the order (z,y,x), if files in impath were (x,y,z) """
    for file_name in glob.glob(path.join(impath, "*.png")):
        ims.append(imageio.imread(file_name))
    return np.array(ims)

def display_vascular_volume(impath):
    im = read_vascular_volume(impath)
    print("shape: " , im.shape)
    print("max value: ", np.max(im))
    view3d.quick_max_projection_viewer(im, z_axis=0)

def main():
    path_to_images = path.join("image1", "original_image")
    display_vascular_volume(path_to_images)

if __name__ == '__main__':
    main()