# Eve Oliker
# July 2023
# import pickle file and save as Matlab workspace

import scipy.io as sio
import numpy as np

file_path = "/path/to/pickle/file"

# load raw pickle file
with open(file_path, 'rb') as f:
    data = pickle.load(f)

# from inside the data dictionary, looks for the sections ‘wavelengths’ and grabs information from subsection ‘Trios’
wavelengths = data['wavelengths']['TriOS']
# looks inside radiance section of data and grabs trios subsection - actual sensor data
raw_trios_data = data['Radiance']['TriOS'] 

# create new empty dictionary
structured_sites = {}

# for loop - looks at every item inside raw trios data - each has 3 parts: station, number, type
# types are - sky, water, spec
for key, array_data in raw_trios_data.items():

# break down the keyname - split wherever there is a space (ex: KR1B_1 Sky)
# make into a list of two parts
    parts = key.split(' ')
        
# prefix - grabs the first part of the split (the site name and replicate number)
# e.g., "KR1B_1"
    prefix = parts[0]    

# data type - grabs the second part and makes lowercase    
    data_type = parts[1].lower()  # "sky", "water", or "spec"
    
# Split the prefix by the last underscore to separate site and replicate
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
# loop repeats for next item in raw trios data until all are sorted
    structured_sites[site_name][rep_id][data_type] = array_data

# Save to a clean mat file for matlab
sio.savemat('Trios_Structured.mat', {'sites': structured_sites, 'wavelengths': wavelengths}) 
