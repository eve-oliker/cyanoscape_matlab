%% TSS_Turbidity with header function (Site & SeaBASS)
% By Eve Oliker
% 06/22/2026

clear;
clc;
addpath = ('/Users/eveoliker/Downloads/'); 

%% Environment Set-up, file path configuration

% Set the folder where this script is located
inputFolder = '/your/filepath/here';

% 1: Grab data from raw data file
inputFile = 'MATLAB_TSS_Turbidity(SeaBASS)_Reference.xlsx';
filePath = fullfile(inputFolder, inputFile);
metaFolder = '/your/metadata/filepath/here';

% 1A: forces SPM (TSS) to input as string text to deal with <5 and <13 values
opts = detectImportOptions(filePath);
opts = setvartype(opts, {'SPM'}, 'string');
mainData = readtable(filePath, opts);

% set all variables to lowercase to prevent issues with matching
mainData.Properties.VariableNames = lower(mainData.Properties.VariableNames); 

% searches SPM column for values with "<" symbol
if ismember('spm', mainData.Properties.VariableNames)
    mainData.spm(ismissing(mainData.spm)) = "";        %clean empty/missing values - make blank
    belowDetect = contains(mainData.spm, "<");         
    mainData.spm(belowDetect) = '-8888';                % replaces anything with "<" to -8888
    mainData.spm = double(mainData.spm);                % convert from string to double
end

%% 2: Import metadata
metadataPath = fullfile(metaFolder, 'BIOSCAPE_metadataTable.xlsx');
metadataTable = readtable(metadataPath);
metadataTable.Properties.VariableNames = lower(metadataTable.Properties.VariableNames);

% initialize blank columns for metadata 
mainData.latitude = zeros(height(mainData), 1);
mainData.longitude = zeros(height(mainData), 1);
mainData.secchi_depth = NaN(height(mainData), 1);
mainData.date = zeros(height(mainData), 1); % Kept as number for yyyymmdd format
mainData.time = duration(NaN(height(mainData), 1), 0, 0);

%% 3: Identify sites and the correlated stations and file names
% creates arrays mapping the 4 sites to their output names
siteNames = {'Rietvlei', 'Klein_River_Estuary', 'Theewaterskloof', 'Zeekoevlei'};
fileNames = {'Rietvlei_TSS_Turbidity.xlsx', 'Klein_River_Estuary_TSS_Turbidity.xlsx', 'Theewaterskloof_TSS_Turbidity.xlsx', 'Zeekoevlei_TSS_Turbidity.xlsx'};

% nested array - maps specific station codes to their parent site defined above
stationsPerSite = {...
    {'RV1A', 'RV1B', 'RV1C', 'RV1D', 'RV1E', 'RV2A', 'RV2B', 'RV2C', 'RV2D', 'RV2E', 'RV3A', 'RV3B', 'RV3C'},...
    {'KR1A', 'KR1B', 'KR1C', 'KR1D', 'KR1E'},...
    {'TW1A', 'TW2A', 'TW2B', 'TW2C', 'TW3A', 'TW3C', 'TW3E', 'TW3F'}, ...
    {'ZK1A', 'ZK1B', 'ZK1C', 'ZK1D', 'ZK1E', 'ZK2A', 'ZK2B', 'ZK2C', 'ZK2D', 'ZK2E', 'ZK3A', 'ZK3B', 'ZK3C', 'ZK3D', 'ZK3E'}...
    };

%% 4: For loop - split data from one file into individual by site
for s = 1:length(siteNames)
    clear project_info; 
    currentSite = siteNames{s};
    currentFile = fileNames{s};
    currentStationList = stationsPerSite{s}; 
    
    % Filter rows belonging to the stations for this site
    siteRowsMask = ismember(mainData.station, upper(strip(string(currentStationList))));
    siteTable = mainData(siteRowsMask, :);            % isolate table rows
    siteTable.station = string(siteTable.station);

   %% 4B: metadata matching loop 
   % for the current station, find the matching rows in the metadata file
   for i = 1:length(currentStationList)
       currentStation = currentStationList{i};
       metaRow = strcmpi(metadataTable.station, currentStation);    % strcmpi = ignore case sensitivity
       dataRows = strcmpi(siteTable.station, currentStation);

       if any(metaRow)
           siteTable.lat(dataRows) = metadataTable.lat(metaRow);
           siteTable.lon(dataRows) = metadataTable.lon(metaRow);
           siteTable.date(dataRows) = metadataTable.date(metaRow); % Keeps numeric yyyymmdd
           siteTable.secchi_depth(dataRows) = metadataTable.secchi_depth(metaRow);
           tempDateTime = datetime(metadataTable.time(metaRow), 'ConvertFrom', 'excel');
           siteTable.time(dataRows) = timeofday(tempDateTime);
       end
   end
    
   %% 5) collect and group weather/ water notes
   siteComments = {};       % create empty array

   stationsInFile = unique(strip(string(siteTable.station)));       % only shows stations with data in the file

   for noteType = ["weather_notes", "water_surface_notes"]
       if ismember(noteType, metadataTable.Properties.VariableNames)
           % Get stations and notes for current site
           % breaks metadata table into smaller table
           % 2 columns: stations, note type
           subTable = metadataTable(ismember(metadataTable.station, stationsInFile), ["station", noteType]);
           % filters subTable to drop blank rows
           subTable = subTable(~ismissing(subTable.(noteType)) & subTable.(noteType) ~= "" & subTable.(noteType) ~= "NA", :);

           % Group matching note strings and join station names
           % findgroups: assigns a group number ID to each unique string
           % G: column array of group IDs matching each station row in subtable
           [G, uniqueNotes] = findgroups(subTable.(noteType));
           % loop through each group index from 1 to the total number of
           % unique notes (max(G))
           for g = 1:max(G)
               % find all stations in subTable assigned to group g
               % joins into single string separated by semicolon
               stns = strjoin(subTable.station(G == g), '; ');
               
                if noteType == "weather_notes"                 % set header label
                    label = "Weather Notes";
                else
                    label = "Water Surface Notes";
                end
                % assemble final string, apend to siteComments
               siteComments{end+1, 1} = sprintf('! %s [%s]: %s', label, char(stns), char(uniqueNotes(g)));
           end
       end
   end
   
   % fill missing secchi depth with missing value -9999
   siteTable.secchi_depth(isnan(siteTable.secchi_depth)) = -9999;
   siteTable.SZ = siteTable.secchi_depth;    % replace with seabass SZ

    %% 6 Call the header function
    % define fields, units, header variables
    fieldsList = {'station', 'turbidity', 'spm', 'lat', 'lon', 'date', 'time', 'SZ'};
    unitsList ={'none', 'NTU', 'mg/L', 'degrees', 'degrees', 'yyyymmdd', 'hh:mm:ss', 'm'};
    dataType = 'bottle';
    projectDocuments = 'TBD';

    % call the header function
    siteTable = siteTable(:, fieldsList);
    headerPath = '/Users/eveoliker/Downloads/';
    project_info = Seabass_project_headers(currentSite, currentStationList, fieldsList, unitsList);
    headerStartDate = project_info.start_date;
    
    % set up the file name matching seabass template
    sbFileName = sprintf('BIOSCAPE-TSS_TURBIDITY-%s-%s-%s-R1.sb', ...
        currentSite, dataType, char(headerStartDate));
    %  make the field for /data_file_name match the ultimate sb output file
    project_info.data_file_name = sbFileName;
    
    % call the header variables defined above
    project_info.data_type = dataType;
    project_info.documents = projectDocuments;
    fields = fieldnames(project_info); % extracts a list of the text labels as an array of strings
    
    %% 7: create header array
    headerCellArray = {}; % start with blank array
    headerCellArray{end+1, 1} = '/begin_header';

    % move through metadata fields
    for f = 1:length(fields)
        fieldName = fields{f};
        val = project_info.(fields{f});
        if isnumeric(val)
            if isempty(val)
                val = ''; % deal with empty numeric arrays
            else
                val = num2str(val); % converts numbers to character array
            end
        end
        val = char(val); % ensure val is a char vector
        % for everything in the header block, use format /field=value
        headerCellArray{end+1,1} = sprintf('/%s=%s', fieldName, val);
    end

    %% insert comments field into header
    % specify additional header fields to be added
    above_detect = {'/above_detection_limit=-7777'};
    below_detect = {'/below_detection_limit=-8888'};

    comments = {'!'
        '!Comments'
        '! For suspended particulate matter (SPM) 1 L of sample water was collected in a plastic bottle and was transported in a dark cooler box and refrigerated at 4 °C until analysis.';... 
        '! SPM was analysed using the gravimetric method (American public health association et al. 2012)';...
        '! A well-mixed sample of known volume (usually 1L) was filtered through a dry pre-weighed GF/F filter (0.7 µm nominal pore size; 47 mm diameter)';...
        '! After filtering the filter paper was dried in an oven at 102-105 °C,';...
        '! cooled to room temperature in a desiccator for 1 hour,';...
        '! and weighed on an analytical balance accurate to the fourth decimal place.';...
        '! SPM = <13 for stations RV1A; RV1B; RV1C; RV1D; and RV1E';...
        '! SPM = <5 for stations RV2A; RV1C; RV2D; RV2E'...
        };
    allComments = [comments; siteComments];

    % insert additional header components and comments above /fields
    insertBlock = [above_detect; below_detect; allComments];
    idx = find(contains(headerCellArray, '/fields='));
    headerCellArray = [headerCellArray(1:idx-1); insertBlock; headerCellArray(idx:end)];
    headerCellArray{end+1, 1} = '/end_header'; % add end header line
  
    %% 6 Exporting:
    % Save directly to Excel files
    outputFile = fullfile(inputFolder, currentFile);
    % replace file if it already exists
        if exist(outputFile, 'file')
            delete(outputFile);
        end
    % In the newly created output file, write metadata cells starting at row 1
    writecell(headerCellArray(:), outputFile, 'FileType', 'spreadsheet', 'Range', 'A1');
    dataStartRow = length(headerCellArray) + 1; 
    dataRangeString = sprintf('A%d', dataStartRow); % Creates a string
    % Write the numerical data rows below the header
    writetable(siteTable, outputFile, 'FileType', 'spreadsheet', ...
        'Range', dataRangeString, 'WriteVariableNames', false);
    fprintf('Saved: %s\n\n', outputFile);
    
    %% Call the file post-processing function 
    % creates the final .sb format file
    convert_excel_to_seabass(inputFolder, dataType, currentSite, headerStartDate);
end
