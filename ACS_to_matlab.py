#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Jul 22 12:11:10 2026
@author: eveoliker
# Move data from AC-S pickle file to Matlab structure
"""

import os
import pickle
import numpy as np
import scipy.io as sio
import pandas as pd

# load pickle file
file_path = "/path/to/pickle/file"
output_dir = "/output/path/here/"

with open(file_path, 'rb') as f:
    ACSdata = pickle.load(f)

structured_ACS = {} # extract and clean data
for station_key, val in ACSdata.items():
    # If the station value is a DataFrame or has a .to_dict() method, convert it
    if hasattr(val, 'to_dict'):

        # Drop duplicate columns (if any) and store as dictionary for MATLAB
        if hasattr(val, 'columns'):

            val = val.loc[:, ~val.columns.duplicated()]
        structured_ACS[station_key] = val.to_dict(orient='list')
    else:
        structured_ACS[station_key] = val

# Save to MATLAB format
sio.savemat(output_file, {'ACS': structured_ACS})
