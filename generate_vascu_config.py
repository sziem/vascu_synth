#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Jun 29 15:06:35 2018

@author: soenke
"""
import numpy as np
from warnings import warn
import os
import sys

# %%
def generate_config_files(n_samples, im_shape, n_term_nodes_max=1000, 
                          box_size=20, min_perf_demand=0.1, 
                          voxel_width = 0.04, random_seed=None):
    """
    n_samples (int): number of config files to generate
    im_shape (tuple): shape in order x, y, z
    n_term_nodes_max (int): maximum number of terminal nodes (randomized)
    box_size (int or tuple): size of boxes of constant demand.
    min_perf_demand (float): minimum demand that should be present at
        perforation point.
    random_seed (int or None): if None, clock time is used.  Otherwise the 
        first call to random generators is seeded with that int, which is then
        increased by 1.
    """    
    # provide names of samples and where to find their configuration
    image_names = list()
    demand_files = list()
    param_files = list()
    
    for i in range(n_samples):
        image_names.append("image" + str(i))
        demand_files.append("demand" + str(i) + ".txt")
        param_files.append("p" + str(i) + ".txt")
    
    np.savetxt("image_names.txt", image_names, fmt='%s', newline='\r\n')
    np.savetxt("image_params.txt", param_files, fmt='%s', newline='\r\n')
    remove_trailing_whitespace("image_params.txt")
    print("have written image_names.txt and image_params.txt")    

    # provide supply map (how existing supply impacts demand).
    # Since I am not sure how to use it, it is the same for all structures.
    supply_pairs = generate_supply_map(im_shape)
    write_supply_map("supply.txt", supply_pairs, im_shape)
    print("have written supply.txt") 

    # currently randomized perf_point, n_term_nodes and demand_map, perf_pressure,
    # term_pressure_divisor
    np.random.seed(random_seed)
    # random seeds for vascu_synth (this way they generate new structures even
    # if other params are constant)
    for i in range(n_samples):
        if i > 0 and random_seed:
            random_seed+=1
        # demand_map
        demand_pairs = generate_random_demand_pairs(
                im_shape, box_size=box_size, random_seed=random_seed)
        write_demand_map(demand_files[i], demand_pairs, im_shape)
        print("have written",  demand_files[i])
        # perf_point
        #np.random.seed(random_seed)
        perf_point=(np.random.randint(0, im_shape[0]),
                    np.random.randint(0, im_shape[1]),
                    np.random.randint(0, im_shape[2]))
        if np.max(read_demand_map(demand_pairs, im_shape)) < min_perf_demand:
            raise RuntimeError("demand in the volume is lower than " +
                               "min_perf_demand everywhere.")
        while read_demand_map(demand_pairs, im_shape)[perf_point[0], perf_point[1], perf_point[2]] < min_perf_demand:
            perf_point=(np.random.randint(0, im_shape[0]),
                        np.random.randint(0, im_shape[1]),
                        np.random.randint(0, im_shape[2]))
        # n_term_nodes
        #np.random.seed(random_seed)
        n_term_nodes=np.random.randint(0, n_term_nodes_max)
        if n_term_nodes > np.prod(im_shape) / 10:
            warn("with the current setting, more than every tenth pixel " +
                 "will become a terminal node.")
        # perf_pressure
        perf_pressure_mean= 133000 # µmHg, value from software's example
        #np.random.seed(random_seed)
        perf_pressure = np.random.normal(perf_pressure_mean, perf_pressure_mean/6)  # 6-sigma-sure that min is above 0
        if perf_pressure < perf_pressure_mean/20:  # clip to heuristic minimal value that looks nice (considering other params are const)
            perf_pressure = perf_pressure_mean/20
        elif perf_pressure > 20*perf_pressure_mean:  # clip to heuristic maximum value that looks o.k. (considering other params are const)
            perf_pressure = 20*perf_pressure_mean
        # term_pressure divisor:
        # I want an asymmetric pdf with min=1.05, mean ~1.6, max~20 (-> hard to design).
        #np.random.seed(random_seed)
        term_pressure_divisor_mean = 1.75  # > 1.6 because of asymmetric pdf to avoid too many low values
        divisor_min = 1.2 # must be > 1
        term_pressure_divisor = np.random.gamma(1.8, 
            (term_pressure_divisor_mean - divisor_min)/2) + divisor_min  # purely trial and error to design this
            
        write_param_file(param_files[i],
                         perf_point=perf_point,    # TODO: should be at border
                         perf_pressure=perf_pressure,     
                         term_pressure_divisor=term_pressure_divisor,  # Default: 1.6,  exactly 1 does not work; term pressure must be smaller, not equal.  Vary between roughly 1.05 and 100
                         n_term_nodes=n_term_nodes,
                         demand_file_name=demand_files[i],
                         random_seed=random_seed,
                         supply_file_name="supply.txt",
                         voxel_width=voxel_width)
        print("have written",  param_files[i])


# %% 
def generate_supply_map(im_shape):
    top_left, bottom_right = (0, 0, 0), tuple(np.array(im_shape)-1)  # x, y, z
    pair = dict(box=top_left+bottom_right, coeff=(0.65, 0.34, 0.01, 7))
    return list((pair,))

def generate_random_demand_pairs(im_shape, box_size=1, random_seed=None):
    """
    Generates array of random floats of shape im_shape drawn from uniform 
    distribution in the half-open interval 0...1 and returns it in the correct
    format for input into write_demand_pairs (a list of dicts).
    
    box_size (int or tuple):  Files generated from this may become quite large.  
    You can specify that not every pixel has a different value, but boxes 
    of box_size to reduce filesize.  If im_shape is not a multiple of
    box_size in some direction, then smaller boxes are used on the right, 
    bottom, and back.
    """
    if isinstance(box_size, int):
        box_size = (box_size, box_size, box_size)
    np.random.seed(random_seed)
    demand_map = np.random.random(im_shape).astype(np.float16)
    # Unfortunately, vascu synth does not want to set pixel by pixel, but box
    # by box. Small boxes become very expensive in memory, thus you can 
    # subsample with box_size
    demand_pairs = list()  # of dicts containing "box" and "demand"
    # it seems like the first row must contain a setting for the entire image.
    # Was having some troubles otherwise, but maybe that was another bug.
    demand_pairs.append(dict(
            box=(0,0,0,im_shape[0]-1,im_shape[1]-1,im_shape[2]-1), 
            demand=1))
    for i in range(0, im_shape[0], box_size[0]):
        for j in range(0, im_shape[1], box_size[1]):
            for k in range(0, im_shape[2], box_size[1]):
                if i+box_size[0]-1 < im_shape[0]:
                    box = (i,j,k,i+box_size[0]-1)
                else:
                    box = (i,j,k,im_shape[0]-1)
                if j+box_size[1]-1 < im_shape[1]:
                    box += (j+box_size[1]-1,)
                else:
                    box += (im_shape[1]-1,)
                if k+box_size[2]-1 < im_shape[2]:
                    box += (k+box_size[2]-1,)
                else:
                    box += (im_shape[2]-1,)
                demand = demand_map[i,j,k]
                demand_pairs.append(dict(box=box, demand=demand))
    return demand_pairs

def read_demand_map(demand_pairs, im_shape):
    """convert a list of demand-pairs to a np-array."""
    demand_map = np.zeros(im_shape)
    for d in demand_pairs:
        left = d["box"][:3]
        right = d["box"][3:]
        demand_map[left[0]:right[0]+1, 
                   left[1]:right[1]+1, 
                   left[2]:right[2]+1] = d["demand"]
    return demand_map

def read_demand_pairs_from_file(demand_file):
    with open(demand_file) as f:
        content = f.read().splitlines()
    im_shape = tuple([int(s) for s in content[0].split()])
    content.pop(0)
    boxes = content[0::2]
    demands = content[1::2]
    demand_pairs = list()
    for j in range(len(boxes)):
        demand_pairs.append(dict(box=[int(s) for s in boxes[j].split()], 
                                 demand=np.float16(demands[j])))
    return demand_pairs, im_shape

# %% write configurations to files in the right way
def write_param_file(file_name,
                     perf_point=(0,0,0),
                     perf_pressure=133000,
                     term_pressure_divisor=1.6,
                     n_term_nodes=200,
                     ratio=2,
                     perf_flow=8.33,
                     viscosity=0.036,  #blood
                     gamma=3,
                     min_distance=1,
                     voxel_width=0.04,
                     closest_neighbors=5,
                     random_seed=0,
                     supply_file_name="O2_supply.txt", 
                     demand_file_name="O2_demand.txt"):
    """
    vary to simulate structures:
        perf_point (integer triplet): Location of root branch
            Default: (0,0,0)
        perf_pressure (float): pressure at the perf_point in µmHg
            High pressure leads to thinner branches
            Default: 133000 µmHg  (slightly heightened blood pressure)
        term_pressure_divisor->term_pressure (float >= 1): 
            pressure at the terminal nodes must be lower than perf_pressure 
            This parameter defines, how much the radii of the branches
            shrink from the root radius.  If term_pressure
            Default: 1.6 (roughly leads to term_pressure=83000 µmHg as given
            in the example param file)
        n_term_nodes->num_nodes (int): number of terminal nodes
            default: 200 (from paper)
        ratio->lambda,mu (float): lambda / mu
            ratio of exponents of the objective function
            loss = sum_over_segments(length_j**mu + radius_j**lambda)
            which is minimized in candidate node selection.
            Here: mu is always set to 1 and lambda is set to ratio.
            A higher ratio leads to longer, but thinner branches
            Default: 2 (minimize volumes of cylindrical segments)
        demand_file_name->oxygenation_map (string to txt-file): 
            high demand increases probability 
            of terminal node creation. zero demand forbids branch here
            Default: "O2_demand.txt"
    
    keep as provided below (unless you know what you are doing).  
    Effect of some parameters may correlate with effect of above parameters:
        perf_flow (float): flow at perf_point in m**3/(h*kg)
            flow, pressure and radius are related
            Default: 8.33 m**3/(h*kg)  
            # NOT SURE WHY THERE IS KG HERE
            # NOT SURE WHERE DEFAULT VALUE COMES FROM BUT OTHER PARAMS WERE REASONABLE
        viscosity->rho (float): viscosity of the fluid in Pa*s
            Default: 0.036 (blood)
        gamma (float): impacts radii of child branches at a bifurcation location
            as in r_parent**gam = r_child1**gam + r_child2**gam
            Default: ~3 (empirical). 
        random_seed (integer, optional): with the same random_seed, same params 
            will yield same structure.  If it is not set or zero, clock time
            is used as random_seed
            Default:  0   (i.e. clock time is used)
        min_distance (integer or float??): minimum distance in mm between a 
            bifurcation point and a candidate node.
            integer according to docs, but shouldn't it be float??
            Default:  1 mm
        voxel_width (float): width of a voxel in mm. Cuboid Voxels are assumed.
            The voxel width parameter of the call to vascu_synth may be 
            different to simulate false sampling.
            Default: 0.04 mm
        closest_neighbors->closest_neighbours (int): number of closest 
            segments considered in  candidate node selection (lower to reduce 
            complexity).
            Default:  5
        supply_file_name (string to txt-file): how the supply to one terminal node 
            impacts demand in surrounding nodes.  Not sure about details
            Default: (0.65, 0.34, 0.01, 7) in the entire image
            
    Note: most of them have reasonable defaults, but in the end i am just 
    interested in getting lots of data
    """
    contents = list()
    contents.append("SUPPLY_MAP: " + supply_file_name)  # separate file
    contents.append("OXYGENATION_MAP: " + demand_file_name)  # separate file
    contents.append("RANDOM_SEED: " + str(random_seed))  # optional.
    contents.append("PERF_POINT: " + arr_to_str(perf_point))  # loc of root
    contents.append("PERF_PRESSURE: " + str(round(perf_pressure))) # µmHg  # does not need to be int, but int-precision is enough
    contents.append("TERM_PRESSURE: " + str(round(perf_pressure/term_pressure_divisor))) # µmHg, 
    contents.append("PERF_FLOW: " + str(perf_flow)) # m**3/(h*kg)
    contents.append("RHO: " + str(viscosity)) # viscosity in Pa*s 
    contents.append("GAMMA: " + str(gamma)) # 
    contents.append("LAMBDA: " + str(ratio)) # 
    contents.append("MU: 1") # see docstring for ratio for why this is reasonable
    contents.append("MIN_DISTANCE: " + str(min_distance)) # mm
    contents.append("NUM_NODES: " + str(n_term_nodes)) # no. terminal nodes
    contents.append("VOXEL_WIDTH: " + str(voxel_width)) # mm
    contents.append("CLOSEST_NEIGHBOURS: " + str(closest_neighbors)) #
    np.savetxt(file_name, contents, fmt="%s", newline='\r\n')
        

# oxygen demand and supply impact  
def write_demand_map(file_name, demand_pairs, im_sh, box_size=1):
    """
    writes 
    pairs: list of dicts containing "box" and "demand" fields.
         "box": indices of the top left (first 3 numbers)
             and bottom right (last 3 numbers)
             of a box using the same coefficients.
             (coordinates in the order x, y, z)
         "demand": number between 0...1, where 0 forbids a vascular structure
             and 1 is high demand.
    """
    # first line contains parsing info (max image indices)   
    demand_map = list()
    demand_map.append(arr_to_str(np.array(im_sh)-1))
    for pair in demand_pairs:
        demand_map.append(arr_to_str(pair["box"]))
        demand_map.append(str(pair["demand"]))
    np.savetxt(file_name, demand_map, fmt="%s", newline='\r\n')

def write_supply_map(file_name, supply_pairs, im_sh):
    """
    pairs: list of dicts containing "box" and "coeff" fields.
         All pairs must have the same number of coeffs.
         "box": indices of the top left (first 3 numbers)
             and bottom right (last 3 numbers)
             of a box using the same coefficients.
             (coordinates in the order x, y, z)
         "coeffs": The coeffs specify how existing supply impacts demand in box.
             Am not sure about the exact funcional form the coeffs represent.
    """
    # first line contains parsing info (max image indices and n_coeffs to use)
    supply_map = list()
    n_coeff = len(supply_pairs[0]["coeff"])  # init
    supply_map.append(arr_to_str(np.array(im_sh)-1) + " " + str(n_coeff))
    for pair in supply_pairs:
        box = pair["box"]
        coeff = pair["coeff"]
        if len(coeff) != n_coeff:
            msg = ("the same number of coefficients must be provided for " +
                   "all boxes in supply_map.")
            raise ValueError(msg)
        supply_map.append(arr_to_str(box))
        supply_map.append(arr_to_str(coeff))
    np.savetxt(file_name, supply_map, fmt="%s", newline='\r\n')


# %% utility functions:
def arr_to_str(a):
    res = str()
    final = len(a)-1
    for i, el in enumerate(a):
        res += str(el)
        if i == final:
            return res
        else:
            res += " "
    warn("The function arr_to_str returned nothing.")

def remove_trailing_whitespace(txt_file):
    with open(txt_file, 'r') as f:
        tmp = f.read().rstrip()
    with open(txt_file, 'w') as f:
        f.write(tmp)

def clear_all_vascu_files(cpath):
    """cpath for current path"""
    cpath = os.path.join(cpath, "original_image")
    if os.path.isdir(cpath):
        print(cpath, "exists. Deleting all files it contains.")
        # TODO: delete only png-files
        for the_file in os.listdir(cpath):
            file_path = os.path.join(cpath, the_file)
            try:
                if os.path.isfile(file_path):
                    os.unlink(file_path)
            except Exception as e:
                raise e

# this does not work well
def run_vascu_synth():
    # TODO: generalize to arbitrary image_names, param_files, voxel_sizes
    import subprocess
    return subprocess.call(["./VascuSynthPng", "param_files.txt", "image_names.txt", "0.04"]) 
    #, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

# %% main

# run_vascu_synth does not work well
def _test():
    print("running test: show config and run vascu synth on config")
    # Testing
    # run vascu_synth and load_first image as test
    from read_vascular_structures import display_vascular_volume 
    
    image_names = np.loadtxt("image_names.txt", dtype=np.str)
    print(image_names)
    param_files = np.loadtxt("param_files.txt", dtype=np.str)
    print(param_files)
    if not image_names.shape:  # empty (contains only one element)
        image_names = [str(image_names),]
    for i in range(len(image_names)):
        #import toolbox.view3d as view3d
#        demand_pairs, im_shape = read_demand_pairs_from_file("demand" + str(i) + ".txt")
#        demand_maps = read_demand_map(demand_pairs, im_shape=im_shape)
#        view3d.quick_slice_viewer(demand_maps, z_axis=0)
        #with open("p" + str(i) + ".txt") as f:
        params = np.loadtxt("p" + str(i) + ".txt", dtype=np.str, delimiter='\r\n')
        print(params)
    # this is run in parallel to below, but running_vascu_synth should 
    # always be slower
    for cpath in image_names:  # current_path
        clear_all_vascu_files(cpath)
#    else:
#        i = 0
#        image_names = [image_names,]
#        params = np.loadtxt("p" + str(i) + ".txt", dtype=np.str, delimiter='\r\n')
#        print(params)
#        clear_all_vascu_files(str(image_names))

    # this forks a new child process and should block the python program until
    # it is done, but this does not always work.
    print("running vascu_synth -- see terminal for info-stream.")
    print("Note that vascu synth will take long -- and not complain in case of invalid input but just get stuck.")
    run_vascu_synth()

    for imfile in image_names:
        try:
            display_vascular_volume(os.path.join(imfile, "original_image"))
        except ValueError as e:
            print("vascu synth not done yet.  For some reason subprocess " +
                  "does not wait for some input shapes.  You need to run " +
                  "vascu_synth manually and then display_vascular_volume")
        except Exception as e:
            raise e
        
def main():
    # TODO: run several in parallel with different random seeds (subprocess)
    print("usage with command line: python generate_vascu_config.py seed n_samples(200 by default)") 
    try:
        seed = int(sys.argv[1])
    except IndexError as e:
        print("you need to specify a seed for the random number generator")
        raise e
    # seed = 11  # TODO: change
    # hyperparams:
    # increasing image size and n_term_nodes will increase computational time
    # per sample significantly
    try:
        n_samples = int(sys.argv[2])
    except IndexError as e:
        print("n_samples not provided. Using default value 200")
        n_samples = 200
    #    im_sh = 3 * (100,)  # for square images
    # max size is about (1000,1000,100), although increasing box_size can make others possible
    im_sh = (400, 100, 100)  # x, y, z; shape of image, i.e indices 0...99
    n_term_nodes_max=500
    box_size=20
    generate_config_files(n_samples, im_sh, n_term_nodes_max, box_size, 
                          min_perf_demand=0.1, voxel_width=0.03,
                          random_seed=seed)
    # TODO: do I need to decrease voxel_width for larger images?

if __name__ == '__main__':
    main()
    # you need view3d for display-part of test which is in 
    # another repo (ml_deconv->toolbox->view3d)
    # or just modify _test routine to your own needs.
    # due to subprocess not consistently blocking during run of vascu_synth,
    # it is recommended to run vascu synth externally
    # _test()
    

# %% Old stuff
    
# Try what happens:
# TODO: could im_sh be different btw demand and supply map?
# TODO: do you need to set coefficients for the entire box in supply map?  
#       what happens otherwise?  Default or exception?
# TODO: Does the arg order always have to be in this order?


# This took me too long already.  Will just create random map
#def generate_demand_pairs(n_maps, im_shape):    
#    # 0 is low, 1 is high. 
#    # values given later override those given before
#    top_left, bottom_right = (0, 0, 0), tuple(np.array(im_shape)-1)  # x, y, z
#    base = dict(box=top_left+bottom_right, demand=1)
#    
#    demand_pairs = list()
#    
#    #uniform demand
#    demand_pairs.append(list(base,))        
#    
#    #exclude left_top_front
#    top_left_sub = top_left
#    bottom_right_sub = tuple((np.array(im_shape)-1)//2
#    demand_pairs.append(list(base,dict(box=top_left+bottom_right, demand=0))  
#
#    demand_pairs.append()

#    if n_maps > len(demand_pairs):
#        msg = ("only " + str(len(demand_pairs)) + " demand maps are " + 
#               "available and you want " + str(n_maps) + ".")
#        raise ValueError(msg)
#
#    # this is not very efficient, but who cares ...
#    return demand_maps[:n_maps]    
    
#    box1 = (0, 0, 0, 99, 99, 99)  # indices of the top left (first 3 numbers)
#                                 # and bottom right (last 3 numbers)
#                                 # of a box with constant O2 demand.
#    demand1 = 1  # demand in box 1.  
#    # 0 is low, 1 is high. 

#    box2 = (0, 34, 34, 99, 44, 44)  # indices of the top left (first 3 numbers)
#                                 # and bottom right (last 3 numbers)
#                                 # of a box with constant O2 demand.
#    demand2 = 0  # 0 is low, 1 is high.


