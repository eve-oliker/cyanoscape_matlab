#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Jul 13 10:20:31 2026

@author: eveoliker
# extract data from GER instrument
# move data from pickle file to Matlab
"""

import os
import pickle
import scipy.io as sio
import numpy as np


file_path = "/Users/path/to/pickle/file"
output_path = "/Users/path/to/output/folder"

# load raw pickle file 
with open(file_path, 'rb') as f:
    data = pickle.load(f)

# from inside the data dictionary, looks for the sections ‘wavelengths’ and grabs information from subsection GER
wavelengths = data['wavelengths']['GER']
# looks inside radiance section of data and grabs GER subsection - actual sensor data
raw_GER_data = data['Radiance']['GER'] 

# create new empty dictionary
structured_sites = {}
# for loop - looks at every item inside raw GER data - each has 3 parts: station, number, type
# types are - sky, water, spec
for key, array_data in raw_GER_data.items():

# break down the keyname - split wherever there is a space (ex: KR1B_1 Sky)
# make into a list of two parts
    parts = key.split(' ')

# safety check
# if len(parts) < 2:
# continue
        
# prefix - grabs the first part of the split (the site name and replicate number)
# e.g., "KR1B_1"
    prefix = parts[0]    

# data type - grabs the second part and makes lowercase    
    data_type = parts[1].lower()  # "sky", "water", or "spec"

# Split the prefix by the last underscore to separate site and replicate
# ex: separate KR1B from 1
    prefix_parts = prefix.rsplit('_', 1)
    if len(prefix_parts) < 2:
        continue
        
# grab the first part (ex: KR1B)
    site_name = prefix_parts[0] 
# second part (1)
    rep_num = prefix_parts[1]    
# add text ‘rep’ before the number to make label (ex: rep1)
    rep_id = f"rep{rep_num}"    

# Initialize nested structure of folders
# check if a folder for site name exists, if not create one
    if site_name not in structured_sites:
        structured_sites[site_name] = {}
# check if a folder for rep_id exists in site folder, if not, create one
    if rep_id not in structured_sites[site_name]:
        structured_sites[site_name][rep_id] = {}
        
# Save the array data into its specific spot
# site → replicate → data type
# structured_sites['KR1B']['rep1']['sky']
# loop repeats for next item in raw GER data until all are sorted
    structured_sites[site_name][rep_id][data_type] = array_data

# create the folder automatically if it doesn't exist yet
if not os.path.exists(output_path):
    os.makedirs(output_path)
    
output_file = os.path.join(output_path,'GER_Structured.mat')
    
# Save to a clean mat file for matlab
sio.savemat(output_file, {'sites': structured_sites, 'wavelengths': wavelengths})
