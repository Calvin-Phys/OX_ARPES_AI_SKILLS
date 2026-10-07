dataFile = string(getenv("ARPES_DATA_FILE"));
mode = string(getenv("ARPES_MODE"));
if strlength(dataFile) == 0 || ~isfile(dataFile)
    error("The ARPES data file is unavailable: %s", dataFile);
end
if isempty(which("loader_UI"))
    error("loader_UI is not on the MATLAB path. Add the ARPES loader package.");
end

beforeLoad = who;
loader_UI(char(dataFile));
newVariables = setdiff(who, [beforeLoad; {'beforeLoad'}]);
if numel(newVariables) ~= 1
    error("Expected loader_UI to create exactly one workspace variable; found: %s", ...
        strjoin(newVariables, ", "));
end

dataVariableName = newVariables{1};
data = eval(dataVariableName);
dataClass = class(data);
if ~ismember(string(dataClass), ["OxA_CUT", "OxA_MAP", "OxA_KZ"])
    fprintf("SKIPPED %s: unsupported data class %s\n", dataFile, dataClass);
    return;
end

thetayOffset = str2double(string(getenv("ARPES_THETAY_OFFSET")));
thetaxOffset = str2double(string(getenv("ARPES_THETAX_OFFSET")));
azimuthOffset = str2double(string(getenv("ARPES_AZIMUTH_OFFSET")));
sliceWidth = str2double(string(getenv("ARPES_SLICE_WIDTH")));
if any(~isfinite([thetayOffset, thetaxOffset, azimuthOffset, sliceWidth])) || sliceWidth <= 0
    error("Offsets must be finite and slice width must be positive.");
end

photonOverride = string(getenv("ARPES_PHOTON_ENERGY"));
workOverride = string(getenv("ARPES_WORKFUNCTION"));
innerOverride = string(getenv("ARPES_INNER_ENERGY"));
if strlength(photonOverride) > 0
    if strcmp(dataClass, 'OxA_KZ')
        error("Do not replace a photon-energy scan with one photon-energy value.");
    end
    data.info.photon_energy = parseScalar(photonOverride, "photon_energy");
end
if strlength(workOverride) > 0
    data.info.workfunction = parseScalar(workOverride, "workfunction");
end

if mode == "momentum"
    if ~isfield(data.info, 'workfunction') || isempty(data.info.workfunction) || ...
            ~isnumeric(data.info.workfunction) || any(~isfinite(data.info.workfunction(:)))
        error("Missing valid info.workfunction. Ask the user for its exact value and pass --workfunction.");
    end
    if ~strcmp(dataClass, 'OxA_KZ') && (~isfield(data.info, 'photon_energy') || ...
            ~isscalar(data.info.photon_energy) || ~isfinite(data.info.photon_energy))
        error("Missing valid info.photon_energy. Ask the user for its exact value and pass --photon-energy.");
    end
    data.info.thetay_offset = thetayOffset;
    if strcmp(dataClass, 'OxA_MAP')
        data.info.thetax_offset = thetaxOffset;
        data.info.azimuth_offset = azimuthOffset;
    elseif strcmp(dataClass, 'OxA_KZ')
        if strlength(innerOverride) > 0
            data.info.inner_energy = parseScalar(innerOverride, "inner_energy");
        end
        if ~isfield(data.info, 'inner_energy') || ~isscalar(data.info.inner_energy) || ...
                ~isfinite(data.info.inner_energy)
            error("Missing valid info.inner_energy. Ask the user for its exact value and pass --inner-energy.");
        end
    end

    if ~strcmp(dataClass, 'OxA_CUT')
        % Convert the source energy planes contributing to the requested slice.
        % A full 3D conversion is much larger and is unnecessary for a PNG.
        if strcmp(dataClass, 'OxA_MAP')
            fermiPosition = data.info.photon_energy - data.info.workfunction;
        else
            fermiPosition = 0;
        end
        selected = abs(data.z - fermiPosition) <= sliceWidth / 2;
        if ~any(selected)
            [~, nearest] = min(abs(data.z - fermiPosition));
            selected(nearest) = true;
        end
        data.z = data.z(selected);
        data.value = data.value(:, :, selected);
        fprintf("Fermi planes converted: %d of %d; center %.9g eV; width %.9g eV\n", ...
            nnz(selected), numel(selected), fermiPosition, sliceWidth);
    end

    dataKspVariableName = [dataVariableName '_ksp'];
    dataKsp = data.kconvert();
    dataKsp.name = dataKspVariableName;
    eval(sprintf('%s = dataKsp;', dataKspVariableName));
    if strcmp(dataClass, 'OxA_CUT')
        dataToShow = dataKsp;
    else
        dataToShow = dataKsp.get_slice('z', 0, sliceWidth);
        dataToShow.name = [dataKspVariableName '_fermi_surface'];
    end
    outputSuffix = "_ksp.png";
    fprintf("Momentum-space variable: %s\n", dataKspVariableName);
    fprintf("thetay_offset: %.9g\n", thetayOffset);
    if strcmp(dataClass, 'OxA_MAP')
        fprintf("thetax_offset: %.9g; azimuth_offset: %.9g\n", thetaxOffset, azimuthOffset);
    elseif strcmp(dataClass, 'OxA_KZ')
        fprintf("inner_energy: %.9g eV\n", data.info.inner_energy);
    end
elseif mode == "raw"
    if strcmp(dataClass, 'OxA_CUT')
        dataToShow = data;
    else
        if strcmp(dataClass, 'OxA_MAP')
            if ~isfield(data.info, 'photon_energy') || ~isfield(data.info, 'workfunction') || ...
                    isempty(data.info.photon_energy) || isempty(data.info.workfunction)
                error("A raw angular map needs photon_energy and workfunction to locate the Fermi surface.");
            end
            fermiPosition = data.info.photon_energy - data.info.workfunction;
        else
            fermiPosition = 0;
        end
        dataToShow = data.get_slice('z', fermiPosition, sliceWidth);
        dataToShow.name = [dataVariableName '_fermi_surface'];
    end
    outputSuffix = ".png";
else
    error("Unsupported ARPES export mode: %s", mode);
end

dataToShow.show();
drawnow;
if ~strcmp(dataClass, 'OxA_CUT')
    title(gca, sprintf('%s: E - E_F = 0 eV', dataVariableName), 'Interpreter', 'none');
end
[dataDirectory, dataBaseName] = fileparts(char(dataFile));
pngFile = fullfile(dataDirectory, dataBaseName + outputSuffix);
exportgraphics(gcf, pngFile, "Resolution", 300);
if ~isfile(pngFile)
    error("MATLAB did not create the PNG: %s", pngFile);
end
fprintf("Input variable: %s; class: %s\nSaved figure: %s\n", dataVariableName, dataClass, pngFile);

function value = parseScalar(text, fieldName)
value = str2double(text);
if ~isscalar(value) || ~isfinite(value)
    error("%s must be one finite numeric value.", fieldName);
end
end
