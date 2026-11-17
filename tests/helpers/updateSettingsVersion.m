% This function changes the version of NMSM Pipeline settings files: in
% every .xml file in a folder and its subfolders whose
% <NMSMPipelineDocument Version="..."> is oldVersion, the version becomes
% newVersion. Files at any other version are left alone, so fixtures that
% test the version check on purpose (bad_major_version.xml,
% edge_minor_version.xml) keep theirs. Only the version is changed; the
% rest of each file, including its line endings, is kept byte for byte.
%
% With DryRun=true, nothing is written and the files that would change are
% returned.
%
% Example, from the nmsm-test folder:
%   updateSettingsVersion("tests/data", "1.5.4", "1.5.5")
%   updateSettingsVersion("tests/data", "1.5.4", "1.5.5", DryRun=true)
%
% (string, string, string) -> (string array)

function changedFiles = updateSettingsVersion(folder, oldVersion, ...
    newVersion, options)
arguments
    folder (1, 1) string {mustBeFolder}
    oldVersion (1, 1) string {mustBeVersion}
    newVersion (1, 1) string {mustBeVersion}
    options.DryRun (1, 1) logical = false
end
pattern = "(<NMSMPipelineDocument\s+Version=[""'])" + ...
    regexptranslate("escape", oldVersion) + "([""'])";
files = dir(fullfile(folder, "**", "*.xml"));
changedFiles = strings(0, 1);
for file = reshape(files, 1, [])
    fileName = string(fullfile(file.folder, file.name));
    bytes = readBytes(fileName);
    text = native2unicode(bytes, "UTF-8");
    newText = regexprep(text, pattern, "$1" + newVersion + "$2", "once");
    if strcmp(newText, text)
        continue
    end
    changedFiles(end + 1, 1) = fileName; %#ok<AGROW>
    if ~options.DryRun
        writeBytes(fileName, unicode2native(newText, "UTF-8"));
    end
end
end

function mustBeVersion(version)
if isempty(regexp(version, "^\d+\.\d+\.\d+$", "once"))
    throwAsCaller(MException("updateSettingsVersion:badVersion", ...
        "A version must look like 1.5.4, not """ + version + """."))
end
end

function bytes = readBytes(fileName)
fileId = fopen(fileName, "r");
closeFile = onCleanup(@() fclose(fileId));
bytes = fread(fileId, Inf, "*uint8")';
end

function writeBytes(fileName, bytes)
fileId = fopen(fileName, "w");
closeFile = onCleanup(@() fclose(fileId));
fwrite(fileId, bytes);
end
