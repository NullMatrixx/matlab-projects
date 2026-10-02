%%-------------------------------------------------------------------------------------------------------------
%Date: 29-09-2026
%Author: Aditya S
%Purpose: This script can find MAT files present in a folder structure and summarize its attributes (if present)
%Version: 1.0
%%-------------------------------------------------------------------------------------------------------------

clc;
clear all;
bdclose all;

try
    % Read directory path from user
    rootDir = input('Enter directory path: ', 's');

    % Validate input
    if isempty(strtrim(rootDir))
        error('Directory path cannot be empty!!');
    end

    if ~isfolder(rootDir)
        error('Invalid directory path: %s', rootDir);
    end

    % Recursively find all .mat files
    matFiles = dir(fullfile(rootDir, '**', '*.mat'));

    if isempty(matFiles)
        fprintf('No .mat files found in: %s\n', rootDir);
        return;
    end

    fprintf('\nFound %d .mat file(s).\n\n', numel(matFiles));

    % Process each MAT file
    for k = 1:numel(matFiles)

        filePath = fullfile(matFiles(k).folder, matFiles(k).name);

        fprintf('============================================\n');
        fprintf('File: %s\n', filePath);
        fprintf('============================================\n');

        try
            % Load MAT file
            data = load(filePath);

            % Get variable names
            varNames = fieldnames(data);

            if isempty(varNames)
                fprintf('No variables found in this MAT file.\n');
                continue;
            end

            tableFound = false;

            % Inspect all variables
            for v = 1:numel(varNames)

                varName = varNames{v};
                value = data.(varName);

                % Check whether variable is a MATLAB table
                if istable(value)

                    tableFound = true;

                    [nRows, nCols] = size(value);

                    fprintf('\nTable variable: %s\n', varName);
                    fprintf('Size           : %d x %d\n', nRows, nCols);

                    % Display table structure
                    fprintf('Columns        : ');
                    disp(value.Properties.VariableNames);

                    fprintf('Column types   : ');
                    disp(varfun(@class, value, 'OutputFormat', 'cell'));

                end
            end

            if ~tableFound
                fprintf('\nNo table variables found in this MAT file.\n');
            end

        catch ME
            % Error while processing individual MAT file
            fprintf('\nERROR processing file:\n%s\n', filePath);
            fprintf('Reason: %s\n', ME.message);
        end
    end

catch ME
    % Error in overall script
    fprintf('\nSCRIPT ERROR: %s\n', ME.message);
end