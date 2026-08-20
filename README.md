# cyanoscape_seabass
Scripts written for the processing of CyanoSCape in-situ data for submisison to NASA's SeaBASS repository.
This document contains MATLAB and Python scripts for the conversion of raw and processed in-situ water quality data into standardized formats (‘.sb’).
Created by Eve Oliker, July 2026.
Several scripts were adapted from the glakes project (https://zenodo.org/records/21683614).

# In-depth information on utilizing scripts. 
## General pipeline structure:
Python pickle to MATLAB structure (‘*_to_matlab_structure.py’): unpacks raw spectral pickle files, formats nested site/ station keys, and exports to structured MATLAB array (‘.mat’)
Python libraries: ‘pandas’, ‘numpy’, scipy’
Calculations and conversions (‘*_calculations_conversions.m’): normalizes radiometric units, applying Mobley 1999 glint corrections, computes summary statistics (median, standard deviation, bincount)

SeaBASS Header and Formatting (‘*_header_sb.m’): maps metadata, formats SeaBASS header blocks, formats non-detect values, converts spreadsheets to ‘.sb’ text files using functions ‘Seabass_project_headers.m’ and ‘Convert_excel_to_seabass.m’

All scripts ending in *_headers_sb follow the same pattern - most clearly outlined for TSS Turbidity. Differences between scripts exist for specific comments, units/fields, data type, etc. These can be found in “Standard Output Data Groups”
Site organization (‘sort_sb_by_site.m’): organizes final ‘.sb’ files into directories by site

Note for future CyanoSCape updates: each *_header_sb file has a line “projectDocuments = ‘TBD’. If this text is replaced with the project document name it will update the /project_documents= line in the resulting files.

# **Functions**
## _Seabass_project_headers.m_
_Note:_ This script has been adapted from those developed by the glakes project https://doi.org/10.5281/zenodo.21683614 
**Purpose:** Uses the master project metadata sheet to generate a standard SeaBASS header structure (project_info) for a target site and list of stations.

**Syntax:** project_info = Seabass_project_headers(siteID, stationList, fieldsList, unitsList) 

**Inputs:**
- **siteID** (string/ character): primary location/ site name (i.e. Rietvlei)
- **stationList** (cell array of strings): list of stations to process (i.e. RV1A, RV1B)
- **fieldsList** (cell array of strings): variable names matching column data (i.e. {‘station’, ‘lat’, ‘lon’, ‘wavelegnth’})
- **unitsList** (cell array of strings): corresponding units for variables in fieldsList {i.e. {‘none’, ‘degrees’, ‘degrees’, ‘nm’})

**Output:** project_info (structure) - contains the SeaBASS header pairs (i.e. start and end date, latitude, fields)

**Explanation:**
- Start with the template header structure “project_info”
- Using [] for blank values to be defined below
- Enter project-level metadata (Investigators, affiliations, contact, experiment, etc)
- Do this either below, or as with missing value -9999, in the structure.
- Bring in metadata information
- Read master metadata sheet
- Match station IDs
- Find spatial bounds and datetime ranges
- Calculate maximum and minimum latitudes/longitudes across matching stations
- Handle Excel decimal time fractions vs hh:mm:ss string durations - append GMT to output string
- Format fields and units into comma-separated SeaBASS header string
- Actual values are specified in the scripts of individual files.

## Convert_excel_to_seabass.m
Note: This script has been adapted from those developed by the glakes project https://doi.org/10.5281/zenodo.21683614
Purpose: turns an excel file created in matlab into a comma delimited “.sb” with the proper SeaBASS formatting and file name.

Syntax: convert_excel_to_seabass(inputFolder, dataType, currentSite, headerStartDate)
- inputFolder - Intermediate directory containing prepared Excel files pre-conversion to .sb format
- dataType - create variable, using seabass options
- currentSite - site for the specific site
- headerStartDate - create variable, will be the date in the file name

Explanation:
- Optional - uses data type to determine the output subfolder
- Uses data type in file name
- Mapping logic - uses string matching contains() on inputFolder
- Routes output .sb files to subfolders (GER, TSS, SE, Chl_A, BB9, Nutrients, ACS, TRIOS)
- Define location of file input and outputs
- Define folder for outputs
- Find the excel files that need to be converted to sb in the input Folder
- Prevents changes to reference or temporary files
- Construct the seabass file name (Using syntax: EXPERIMENT-NAME-DATATYPE_YYYYMMDDHHMM_RELEASE#.sb)
	- if/else - find the data source specified in the file name and use to determine data type
- sbFileName = create the output file name
- Specify data type in specific script
- Create output file, remove additional/ unnecessary header lines created by excel/csv
- Reads contents cell-by cells, find the true first and last line of the header, preserve lines within header block (from /begin_header to /end_header)
- Remove trailing commas
- After the header, treat information as a string and drop any blank/ missing values
- If duration is used in the header, make sure the format is hh:mm:ss
- Fprintf: set up data rows as comma delimited strings

# Final organization - files into subfolder by site
## sort_sb_by_site.m
- Used after all other processing is done - organizes files into subfolders by their station name
- Set directory, target folders, site/station mapping
- Set target folders with the exact names of the data type in use
- Nested loops: scans all generated .sb files in the output directory
- Matches station codes in file name to target site mapping
- Moves each file into the correct site subfolder.

# Data Groups
## Unique features of scripts:
- TSS Turbidity: replace non-detect values (<5, <13) with -8888
- Chlorophyll-a: standardize column headers from chla to chl_a
- BB9 Optics: renames spectral columns from “wvl” to “bb”
- Nutrients: process dissolved carbon, particulate carbon, nutrients.
- AC-S: unpacks pickle file, extract bincount, remove redundant column
- Radiometry (TriOS, SE, GER): converts raw units, applies Mobley glint correction, calculates Lw and Rrs

Simplified pipeline explanation for scripts ending in *_header_sb.m. 
- Read master metadata file
- Filter raw observations - using masking of sites and stations
- Comments - compile notes on water, water surface
- Call function Seabass_project_headers.m to generate north, south, east, west coordinates, time ranges, SeaBASS metadata
- Write temporary Excel file with header and data
- Call function convert_excel_to_seabass.m to generate text .sb 

## TSS_Turbidity_header_sb.m
This script is currently the primary reference for all data conversion scripts, with specific changes noted for each script.

Input: Received raw data as CSIR certificate files and moved into excel sheet with rows for station, TSS, turbidity

Note: the weather/ water notes format for this script are repeated in the scripts for BB9, CHLA, and Nutrients. Other scripts use other formats, specified below.

**1: Set input folder and find file with all raw data**
- filePath: file with raw data
- mainData: read variable filePath
- Set all variable names to lowercase to ensure matching
- 1A (OPTIONAL) : Dealing with raw <5 and <13 values (not acceptable in seabass)
- Read values as a string using “setvartype”
- Clean empty values with “ismissing”
- Define “below detect” units (anything with “<”
- Replace those below detect values with matlab non-detect marker (-8888)
- Now that everything is numeric, convert back from a string to double
- Define above and below detection limit

**2: Blank metadata columns**
- Import and read the metadata file
- Set variable type for station column to string, set all variable names to lowercase to ensure matching
- Create blank columns for the station-specific metadata to be filled into (lat/lon/date/time) in mainData 

**3: Identify sites (and correlated stations and file names)**
- Create array with the 4 site names (ie. Rietvlei; siteNames = main sites).
- Map the output files that correspond to the sites (ie. RV1A) (fileNames = define output files (non seabass))
- Using a nested array - map all station names within each site (stationsPerSite = define any substations within main sites)

**4: For loop - brings data for each site one at a time**
- Moving through the substations that match the sites defined above, the loop moves through mainData and filters through the - “station” column, bringing stations for the current site into a new sheet (siteTable). 

**4A: Create site table**
- currentSite = current site as each loop moves through siteNames
- siteRowsMask: creates a logical array (true/false) values that mark each row that matches stations for the current site in mainData  
- Converts list of station names into a string array
	- Strip = removes leading/trailing whitespace; Upper = converts station names to uppercase
	- Ismember: checks every row in mainData.station. If a row’s station matches any station in the current station list, it is marked as true.
	- siteTable = filters the entire table, selecting only the rows where siteRowsMask is true (only the data for the stations of the current site). The subset of rows is saved to a new table (siteTable)
	- String = makes sure the new siteTable is a string array 

**4B: Metadata matching loop**
- Looks through metadata table by station name to extract coordinates, collection dates, times, secchi depth, and times (converting decimal fractions to hh:mm:ss GMT)
- For loop: runs through each station through the array of station names for the specific site, matches stations against BIOSCAPE_metadataTable.xlsx 
	- currentStation = extracts the specific station name for the current run
	- metaRow and dataRows = create logical arrays, comparing station names
	- metaRow: compares currentStation against every entry in the station column of the metadata table. Gives one “true” at metadata row where the station is found
	- dataRows: compares currentStation against every entry in the station column of the filtered siteTable. Marks all data at that specific station “true”
	- if any = makes sure that at least one “true” exists in metaRow.
- Copy the values for latitude, longitude, and date from every matching row in siteTable. The value is assigned to all rows marked “true” in dataRows.
- Excel’s decimal system is converted into a duration format (hh:mm:ss). Starts with DateTime and removes the date component, leaving the time as a duration

**5: Collect and group weather/ water notes**
- Create empty array (siteComments {}) - mapping table with site name and header title. Loops through the array twice (for weather and then for water)
	- Only writes notes from stations present in the file (filter with “unique”)
- Using stations and notes for the current site, breaks metadata into smaller table (subTable) and removes blank rows
	- Group matching note - joins group names.
	- Findgroups: assigns a group number ID to each unique note string
	- G: column array of group IDs matching each station row in subTable
- For loop - loops through each group index from 1 to the total number of unique notes (max(G))
	- Strjoin: finds all stations in subTable assigned to GroupG
- Set header label (either weather notes or water surface notes)
- Assemble final string and append to siteComments
- Replace missing secchi depth with -9999 and rename secchi_depth to SZ
	- Secchi depth initializes mainData.secchi_depth = NaN initially when setting up metadata columns. During site and station loop, pulls siteTable.secchi_depth (dataRows)

**6: Call the header function**
- Define fields and units, data type, name of project documents
- Preserve output fields safe in siteTable.
- Call the header function Seabass_project_headers() - generates metadata
- Set the output name for the file, define data type, project name, match the seabass header /data_file_name to the output name
- Fill the header lines for data type and project name with section above

**7: Create the header array**
Start with an empty cell array to be filled
- For loop: 
	- Run through every field of the project_info structure (ex:investigators, experiment, affiliation, etc).
	- fieldName: pulls the text name of the current field
	- val: access the field name stored in the variable “f”
	- All header output should be text strings
	- isnumeric checks fs value is number instead of text; isempty converts to an empty array, Num2str: converts numbers into character arrays; val = char(val) = makes sure val is stored as a character array instead of a string object
	- Format into SeaBass syntax (sprintf(‘/%s=%s’, fieldName, val) formats into syntax /name=value)

- Define specific fields to be added and comments block
- Add any fields specific to the file group (i.e. instrument manufacturer, below detection limit)
- Create comments block (formatted with ! at start of each line for SeaBASS)
- allComments: merge the typed comments block with the siteComments (weather and water)
- insertBlock = call all newly created variables and insert them above the /fields section

** 8: Exporting to SeaBASS format: **
- For excel: deletes any existing file, writes the header starting at A1, puts the site table below the header 
- For seabass: calls function convert_excel_to_seabass() - makes the seabass files in their own folder

## Chl_A_headers_sb.m
- Expects a single excel sheet, with metadata (lat/lon/date/time/volfit) in the raw file
- Output: uses “append” rather than “legnth(headerCellArray) + 1” - find description in Nutrients_headers_sb (Matches Nutrients, Chl_A, ACS)
- Lines 45-46: Rename chla to chl_a if present

## BB9_Optics_headers_sb.m
- Expects single dataset (All_BB9.xlsx)
- Target sites differ (no data from Klein River Estuary)
- Instrument information: adds header rows for instrument_manufacturer and instrument model (same logic as adding detection limits)
- Under “load BB9 data set” - regexprep dynamically renames wavelength column from wvl to bb
- Output: uses “append” rather than “legnth(headerCellArray) + 1” - find description in Nutrients_headers_sb

## Nutrients: 
### Nutrients_BIOSCAPE.m 
- Nutrients: read data, clean additives on station names
- Define variable names
- Calculate mean, standard deviation, bincount for each variable
- Rename variables to match SeaBASS requirements
- For loop: finds column for mean, std, bincount, creates and fills columns

**Liquid Carbon:**
- Works only with dissolved type
- Identify data columns
- Run groupsummary (mean, std, bincount)
- Sets below detection limit values to -8888 and missing (NaN values to -9999); Bincount excludes -8888 and -9999
- Rename columns to match SB
- Uses for loop - same logic as above

**Particulate carbon**
- Volume filtered is 30 mL for all samples
- Unit conversions
- Calculated total mass in mg (using metadata info), converted to mg/m^3
- Define and rename variables and coverts units where necessary
- Same for loop logic
- Site and station
- Use metadata for lat/lon/date/time columns
- Split main raw data sheet up by site
- Save each sheet’s data to excel file

_Previous version combined the three file types into one master document_
Using outerjoin on station - merges nutrients, liquid carbon, and particulate carbon tables:
_tempTable = outerjoin(nutrientsSeaBassTable, liquidSeaBassTable, 'Keys', 'station', 'MergeKeys', true); 
masterSeabassTable = outerjoin(tempTable, partSeaBassTable, 'Keys', 'station', 'MergeKeys', true);_

### Nutrients_header_sb.m
- Used raw data to create 3 raw data files to reference, for nutrients, liquid, and particulate
- Logic mainly matches the script TSS_Turbidity_Headers_SB
- Format: read raw files, match metadata, format custom seabass header blocks, exporting output files for conversion to .sb.
- Expects four separate input Excel files pre-split by site in the source folder (Rietvlei_Nutrients, Zeekoevlei_Nutrients, etc). Each site file is looped. 

Differences between TSS and Nutrients:
- Fields and units - Additional header variable /below_detection_limit
- Secchi depth:
	- Checks if secchi_depth exists as a column name in the site Excel sheet (if missing, add column of NaN; If present, standardize header name to secchi_depth)
- Loops through stations, populates siteTable.secchi_depth(dataRows) from metadataTable.secchi_depth(metaRow)
- Output files:
	- Output files end with _prepped (optional) into an output subfolder
	- Uses “append” - Writes header array starting at cell A1. The method used for nutrients has potential risks. If adapting the scripts, the method used for TSS Turbidity is recommended to avoid potentially adding data beneath empty rows.

## AC-S: 

### ACS_to_matlab.py
- Load ‘all_ACS_data.pkl’
For each item
- Check if is pandas data frame or series, drop duplicates
- Converts dataframes to python dictionaries (to_dict(orient=‘list’))
- Use np.array () to convert lists and numpy array
- Use input path to determine destination folder (os.path.dirname())
- Save object as matlab structure array
** AFTER THE ACS TO MATLAB: “converted_data.mat” was used to export to Excel. Opens the .mat structure file, attaches spectral variable column names, and extracts station arrays into individual .xlsx files

### ACS_headers_sb.m
- Uses the structure array created above.
- Same overall logic as above - populate seabass headers and metadata info.
- Generates individual files for every substation
- Uses summary CSV (ACS_station_N_summary.csv) to pull station counts and add bincount into the header. Matches summary bin counts using station identifiers
- Uses “append” method for writing - like Chl_A and Nutrients
- Removes column 4 - c_wavelength (because in this case wavelengths for a and c are identical)

## Radiometric (TriOS, SE, GER):
All scripts go in order of:
1. *_to_matlab_structure.py: convert from pickle file to matlab structure
2. Take structured .mat files from Python
3. Add sensor-specific conversion units
4. Calculate replicate stats across wavelengths
5. Use Mobley 1999 glint-correction
6. *_calculations_conversions: unit conversions and set-up of files in matlab
7. *_headers_sb: typical header script as seen above

### TriOS
#### Trios_to_Matlab_structure.py
- Overview: reorganizes nested TriOS data stored in .pickle file into a MATLAB structure
- Input: Pickle file with raw TriOS spectral radiometer measurements (TriOS_GER_SE_Rrs_dictionary_03_26_26_final.pickle)

- Pull array metadata:
	- Extracts sensor wavelengths (data[‘wavelegnths’][TriOS’])
	- Extracts raw radiance measurements (data['Radiance']['TriOS'])
Loops for each key
- Breaks text keys into three metadata components: station/ site name, replicate number, and data type (sky, water, or spec)
- Split on space to separate station_number from measurement type (ie. ‘KR1B_1’ and ‘sky’)
- Split prefix on rightmost underscore (.rsplit(‘_’, 1)): separate station from replicate (‘KR1B’, ‘1’)
- Rebuilds nested dictionary hierarchy (Groups data sequentially by site → replicate → data type)
- Exports a structure workspace file (Trios_Strutured.mat) which contains the organized nested dictionary and wavelength arrays for MATLAB
- scipy.io.savemat() - saves Trios_Strutured.mat with two variables - site and wavelengths

#### TRIOS_calculations_conversions.m
- Using the file created by Trios_to_Matlab.py - (Trios_Structured.mat)
- Conversions: Convert mW/(m^2 * nm * sr) to μW/(cm^2 * nm *sr) → Conversion factor of 0.1
- Statistics:
	- For each site make blank matrixes the necessary rows
	- Separate data labelled water, spec, sky
	- Calculates median, standard deviation, and bincount (non NaN) for all replicates for each wavelength
	- Calculate for water radiance (Lt), and sky radiance (Lsky). Es values for TriOS are direct from the cosine collector, no conversion necessary.
	- Radiometric Equations (Using Rg value of 0.98 and current replicate to calculate Lw and Rrs)
- Build site table, exports individual Excel spreadsheets with Lsky, Lt, Lw, and Rrs statistics 

#### TRIOS_headers_sb.m
Uses TSS writecell method
Input: excel sheets from TRIOS_calculations_conversions (see above)

### Spectral Evolution (SE)
#### SE_to_matlab_structure.py
See TriOS_to_matlab.py above.
- Opens pickle file, pulls data ['wavelengths']['SE'] and data['Radiance']['SE']
- Splits identifiers using key.split and .rsplit
- Maps array into hierarchy, creates target dictionary
- Exports to SE_Structured.mat

#### SE_calculations_conversions.m
Input file: “SE_structured.mat” (created by  SE_to_matlab.py)
- Conversions: From W/(m^2 * sr *nm) to μW/ (cm^2 * sr * nm); Conversion factor: 100 
- Statistics: Median, standard deviation, and bincount across replicates for plaque, sky, and water
- Same steps as above for TRIOS, but with Es calculated and not collected from cosine collector.

#### SE_headers_sb.m
- Same logic as above
- Input folder: SE_CyanoSCape_Raw_Rrs. Alternative - sheets from SE_to_mtlab.m
- Writetable with explicit starting range: matches TSS_Turbidity

### GER
#### GER_to_matlab_structure.py
- See TriOS_to_matlab.py above.
- Identical structure to SE_to_matlab.py, Targets GER wavelengths and radiance

#### GER_calculations_conversions.m
- Conversions: W/(cm^2 * nm * sr * 10^10) to μW/ (cm^2 * nm *sr); Conversion factor: 1e^-4
- Stats: Same as SE
- Radiometric: Calculates Es, Lw, and Rrs using Mobley glint correction with Rg = 0.98 and p = 0.028

#### GER_headers_sb.m
- Reference file: GER_Structured.mat
- Logic of above
- Input: sheets from GER_to_mtlab.m
- _Potential issue - station TW2D does not exist elsewhere or have metadata information_
- Calibration file = is currently unassigned “file name here” 
- Secchi depth is inserted relative to measurement depth rather than water depth (not intentional difference)

## Particulate_Absorption_Update.m
- This script does NOT follow the format of the rest - as files were received as .sb and only changes to specific header lines were required
- To use: change folderPath to raw .csv folder, change baseDownloadsFolder to working directory, change metadataTable to correct location and file

1: Set folder paths and load metadata
- Set folder path for .sb files (In reference files folder: Particulate-Processed-Seabass)
- Import and read metadata file (BIOSCAPE_Metadata Table)
- Forces station to be a string
- Standardize column names to lowercase
- Cleans station identifiers - remove extra spaces, make all uppercase
- Define exact string values to overwrite previous text in the header (documents and affiliation)
- For each file in the folder - retrieve file name and folder location

2: format SeaBASS output name
- Define file name format “BIOSCAPE-AP-SITE_NAME-scan-yyyymmdd-R1.sb
- tempName - replaces prefix variations in file name with same BIOSCAPE-AP prefix
- Standardize prefix to BIOSCAPE-AP
- Remove 2023 (on its own) from file name
- startDate - read line by line through the header to find the sampling date (/start_date = yyyymmdd)
- Once found, date is saved as string to startDate (token) and closes file
- Pattern: uses expressions to assemble a file name with the pattern 
	- $1, 2, 3, 4, = regex backreferences
	- $1 = BIOSCAPE-AP-
	- $2 = ([^_]+)  : site name (characters before the next _)
	- $3 = (Rep\d+) : replicate (Rep) followed by digit

3: organize output folders and subfolders: Mirror any subdirectories organizing raw files for output folder

4: clean-up header using metadata information
- Load raw file contents as text block
- Extract station name from header tag “/station =”
- Meta row: find matching station row in metadata table
- Remove previous unnecessary header lines (cloud percent, wind speed, wave height, secchi depth); Remove empty comment lines with only “!”
- If any(metaRow): extracts values from metadata for secchi, weather, and water surface matching the station. Fill missing/ blank fields with “NA”
- secchiLine = inserts updated secchi depth below measurement depth
- Overwrites documents, affiliation, data file name with values defined in section 1 

5: update comments
- Formats comment block with weather and water surface observations
- Inserts weather/ water text after specific comment line “The visible to UV…), or above the /end_header tag if the specific comment line is not present

6: write output file
- Check if existing output file with the same name exists - if it does, deletes files to avoid issues
- Writes updated header and data to directory as .sb files
