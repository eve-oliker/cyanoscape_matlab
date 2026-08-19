% Load TRIOS pickle file into matlab
% By Eve Oliker
% Updated on 06/20/2026
clear;
clc;

%%
filePath = "/path/to/matlab/structured/file";
outputDir = "/path/to/output/directory";

% Load structured data from python
load(filePath); % Loads 'sites' and 'wavelengths'
wvls = wavelengths(:);
numWvls = length(wvls);
siteNames = fieldnames(sites);

%% conversions
%cosine_conversion - from mW/(m^2 nm) to uW/cm^2/nm
% 0.1 (uW/(cm^2))/nm
% sky and water final unit: uW/cm^2/nm/sr
% convert from mW/(m^2 nm Sr) to uW/cm^2/nm/sr
conversion_factor = 0.1;

%% Process each site 
for s = 1:numel(siteNames) % numel: returns total number of elements in an array
    currentSite = siteNames{s}; % for each site
    
    % Get all replicate IDs for site
    replicates = fieldnames(sites.(currentSite));
    numReps = numel(replicates);
  
    % Temporary matrices to hold raw data
    % Total rows for this site = wavelengths * number of replicates
    Rrs_matrix = zeros(numWvls, numReps);
    Lw_matrix  = zeros(numWvls, numReps);
    totalRows  = numWvls * numReps; 
    
    raw_Lt     = zeros(numWvls, numReps);
    raw_Lsky   = zeros(numWvls, numReps);
    raw_Es = zeros(numWvls, numReps); % direct Es from TriOS

    % make column for replicate IDs (totalRows from line 28)
    tbl_rep = cell(totalRows, 1); 
    
    %% extract data for all replicates
    for r = 1:numReps 
        currentRep = replicates{r};
    
        rowIdx = (r-1)*numWvls + 1; % counts number of replicates
        endIdx = r * numWvls;
        tbl_rep(rowIdx:endIdx) = repmat({currentRep}, numWvls, 1);
        repData = sites.(currentSite).(currentRep);
    
        % Extract arrays (water, sky, spec) into matrices
        if isfield(repData, 'water')
                raw_Lt(:, r) = repData.water(:) * conversion_factor;
        end
        if isfield(repData, 'sky')
            raw_Lsky(:, r) = repData.sky(:) * conversion_factor;
        end
        if isfield(repData, 'spec')
            raw_Es(:, r) = repData.spec(:) * conversion_factor;
        end
    end

%% calculate summary stats for wavelengths
  % 2 = calculate across(dimension 2)
  % dimension 1 = rows (wavelength), dimension 2 = columns (replicate)
  % median rawLt, 2 : collapse columns and do math individually across each row
  % for sd: 0 = use default weight (standard normalization)

  % collapse replicate columns to calculate median, sd, and bincount for
  % every wavelength

    % Lt (water)
    tbl_Lt_median   = median(raw_Lt, 2);
    tbl_Lt_sd       = std(raw_Lt, 0, 2);
    tbl_Lt_bincount = sum(~isnan(raw_Lt), 2); % Counts non-NaN replicates per wavelength
    
    % Lsky
    tbl_Lsky_median   = median(raw_Lsky, 2);
    tbl_Lsky_sd       = std(raw_Lsky, 0, 2);
    tbl_Lsky_bincount = sum(~isnan(raw_Lsky), 2);
    
    % Es (direct from Trios collector)
    tbl_Es_median   = median(raw_Es, 2);
    tbl_Es_sd       = std(raw_Es, 0, 2);
    tbl_Es_bincount = sum(~isnan(raw_Es), 2);
    
   %% RADIOMETRIC CALCULATIONS
   % Rg = known irradiance reflectance of the reference panel/ ratio of
   % upwelling plane irradiance (Eu) to down welling plane

   % Rho factor = glare correction factor
   rho_factor = 0.028;
 
       for r = 1:numReps
           %currentRep = replicates{r};
           %repData = sites.(currentSite).(currentRep);

           % Extract data for this specific replicate set
            current_Lt   = raw_Lt(:, r);
            current_Lsky = raw_Lsky(:, r);
            current_Es   = raw_Es(:, r); %

            %% Lw (water leaving spectral radiance) using mobley
            % L_t = total observed water leaving radiance
            % L_s = observed sky radiance
            Lw_matrix(:, r) = current_Lt - (rho_factor .* current_Lsky);
           
            %% Rrs (remote sensing reflectance)
            % tbl_Rrs = tbl_Lw ./ tbl_Es;
            Rrs_matrix(:, r) = Lw_matrix(:, r) ./ current_Es;

       end
       % final median values across replicates for site to put in summary table
       tbl_Rrs = median(Rrs_matrix, 2); % Median across column (dimension 2)
       tbl_final_Lw  = median(Lw_matrix, 2);    
    
%% BUILD THE FINAL SITE TABLE
siteTable = table(...
    wvls, ...
    tbl_Lsky_median, tbl_Lsky_sd, tbl_Lsky_bincount, ...
    tbl_Lt_median, tbl_Lt_sd, tbl_Lt_bincount, ...
    tbl_Es_median, tbl_Es_sd, tbl_Es_bincount, ...
    tbl_final_Lw, ...
    tbl_Rrs, ...
    ...
    'VariableNames', {...
    'Wavelength', ...
    'sky', 'sky_sd', 'sky_bincount', ...
    'Lt', 'Lt_sd', 'Lt_bincount', ...
    'Es','Es_sd', 'Es_bincount', ... ...
    'Lw', 'Rrs',
    });

% Save to workspace named after the site
    cleanName = regexprep(currentSite, '[^a-zA-Z0-9_]', '_');     
    % regexprep = search for pattern and replace)
    eval([cleanName, '_Rrs_raw_data_table = siteTable;']);
    % eval = evaluates a text string as an expression/ statement

% save to folder as excel file
% names the file based on the site
    fileName = sprintf('%s_TRIOS_Rrs_all_data.xlsx', cleanName);
    fullExportPath = fullfile(outputDir, fileName);
    writetable(siteTable, fullExportPath);
end
