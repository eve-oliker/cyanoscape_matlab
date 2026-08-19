% Load Spectral-Evolution (SE) data into Matlab
% Eve Oliker
% June 2026

clear; clc;

filePath = "path/to/matlab/structure";
outputDir = "output/file/path";
load(filePath);

%% Load structured data
load(filePath); % Loads 'sites' and 'wavelengths' and calculated Rrs

wvls = wavelengths(:);
numWvls = length(wvls);
siteNames = fieldnames(sites);

% convert units from W/m^2/sr/nm to uW/cm^2/sr/nm
% (1 W = 10^6 uW), convert to m2 to cm2 - divide by 10^4
conversion_factor = 100;

%% Process each site 
for s = 1:numel(siteNames) % numel: returns total number of elements in an array
    currentSite = siteNames{s};
    % Get all replicate IDs for this site (e.g., 'rep1', 'rep2')
    replicates = fieldnames(sites.(currentSite));
    numReps = numel(replicates);
    Rrs_matrix = zeros(numWvls, numReps);
    totalRows = numWvls * numReps; % Total table rows for this site = wavelengths * number of replicates
    
    % Temporary matrices for hold raw data: [numWvls x numReps]
    raw_Lt     = zeros(numWvls, numReps);
    raw_Lsky   = zeros(numWvls, numReps);
    raw_plaque = zeros(numWvls, numReps);

    tbl_rep = cell(totalRows, 1); % Allocate table column for replicate IDs (totalRows)
    %% extract data for all replicates
    for r = 1:numReps 
        currentRep = replicates{r};
    
        rowIdx = (r-1)*numWvls + 1; 
        endIdx = r * numWvls;
        tbl_rep(rowIdx:endIdx) = repmat({currentRep}, numWvls, 1);
        repData = sites.(currentSite).(currentRep);

        % Extract arrays (water, sky, spec)
        % update to match array - pickle has 3 indexes of 0, 1, 2
        % 0 is wavelegnth, 1 is data, 2 is notes
        if isfield(repData, 'water')
                waterData = repData.water{2};
                raw_Lt(:, r) = waterData(:) * conversion_factor;
        end
        if isfield(repData, 'sky')
            skyData = repData.sky{2};
            raw_Lsky(:, r) = skyData(:) * conversion_factor;
        end
        if isfield(repData, 'spec')
            specData = repData.spec{2};
            raw_plaque(:, r) = specData(:) * conversion_factor;
        end
    end

%% calculate summary stats for wavelengths
  % median rawLt, 2 --> collapse columns and do math individually across each row
  % for sd: 0 = use default weight (standard normalization)

    % Lt (Water) Stats
    tbl_Lt_median   = median(raw_Lt, 2, 'omitnan');
    tbl_Lt_sd       = std(raw_Lt, 0, 2, 'omitnan');
    tbl_Lt_bincount = sum(~isnan(raw_Lt), 2);
    
    % Lsky Stats
    tbl_Lsky_median   = median(raw_Lsky, 2, 'omitnan');
    tbl_Lsky_sd       = std(raw_Lsky, 0, 2, 'omitnan');
    tbl_Lsky_bincount = sum(~isnan(raw_Lsky), 2);
    
    % Plaque (Spec) Stats
    tbl_plaque_median   = median(raw_plaque, 2, 'omitnan');
    tbl_plaque_sd       = std(raw_plaque, 0, 2, 'omitnan');
    tbl_plaque_bincount = sum(~isnan(raw_plaque), 2);
    
   %% RADIOMETRIC CALCULATIONS
   
   % Rg = known irradiance reflectance of the reference panel/ ratio of upwelling plane irradiance Eu to downwelling plane
   R_g = 0.98;
   rho_factor = 0.028;

   tbl_Es = (pi / R_g) .* tbl_plaque_median;
   tbl_Lw = tbl_Lt_median - (rho_factor .* tbl_Lsky_median);
   tbl_Rrs = tbl_Lw ./ tbl_Es;

%% BUILD THE FINAL SITE TABLE
siteTable = table(...
    wvls, ...
    tbl_plaque_median, tbl_plaque_sd, tbl_plaque_bincount, ...
    tbl_Lsky_median, tbl_Lsky_sd, tbl_Lsky_bincount, ...
    tbl_Lt_median, tbl_Lt_sd, tbl_Lt_bincount, ...
    tbl_Es, ...
    tbl_Lw, ...
    tbl_Rrs, ...
    'VariableNames', {...
    'Wavelength', ...
    'plaque', 'plaque_sd', 'plaque_bincount', ...
    'sky', 'sky_sd', 'sky_bincount', ...
    'Lt', 'Lt_sd', 'Lt_bincount', ...
    'Es', 'Lw', 'Rrs'
    });

% Save to workspace named after the site
    cleanName = regexprep(currentSite, '[^a-zA-Z0-9_]', '_');     % regexprep = search for regular expression pattern and replace)
    eval([cleanName, '_Rrs_SE_raw_data_table = siteTable;']);

% save to folder as excel file, name the file based on the site
    fileName = sprintf('%s_SE_Rrs_all_data.xlsx', cleanName);
    fullExportPath = fullfile(outputDir, fileName);

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    if isfile(fullExportPath)
        delete(fullExportPath);
    end

    writetable(siteTable, fullExportPath);
    fprintf("Exported: %s", fileName);
end
