% This function copies the part of the nmsm-tutorial Step 8 surrogate model
% data (Step-8-Synergy-Driven-Treatment-Optimization/surrogateData, 28 MB)
% that Treatment Optimization reads into tests/data/to/synergy/surrogateData
% (about 3 MB).
%
% On candidate-1.5.4, parseTreatmentOptimizationDataDirectory reads only:
% - IKData/<trial>.sto, the sampled joint angles (1,575 rows: 63 frames x
%   25 Latin hypercube samples);
% - MAData/<trial>/*_Length.sto, the muscle-tendon lengths;
% - MAData/<trial>/*_MomentArm_<coordinate>.sto, for each coordinate in
%   <surrogate_model_coordinate_list>.
% The other 93 MuscleAnalysis files are never opened. The selected files are
% copied unchanged, with every sample, so the surrogate model fitted from
% them is the tutorial's.
%
% Only run this when the tutorial's surrogate data changes on purpose.
%
% Usage, from the nmsm-test folder, with the tutorial's Step 8 folder (a
% checkout or a git archive of the commit in tests/data/to/README.md):
%   addpath("tests/data/to/synergy")
%   selectSurrogateData("../nmsm-tutorial/Step-8-Synergy-Driven-Treatment-Optimization")
%
% (string) -> (None)

function selectSurrogateData(stepFolder)
trialName = "drive_kick1";
coordinates = ["hip_flexion_r", "hip_adduction_r", "hip_rotation_r", ...
    "knee_angle_r", "ankle_angle_r", "subtalar_angle_r"];
source = fullfile(stepFolder, "surrogateData");
target = fullfile(fileparts(mfilename("fullpath")), "surrogateData");
if isfolder(target)
    rmdir(target, "s");
end
mkdir(fullfile(target, "IKData"));
mkdir(fullfile(target, "MAData", trialName));
copyfile(fullfile(source, "IKData", trialName + ".sto"), ...
    fullfile(target, "IKData"));
suffixes = ["_Length.sto", "_MomentArm_" + coordinates + ".sto"];
for suffix = suffixes
    file = dir(fullfile(source, "MAData", trialName, "*" + suffix));
    assert(isscalar(file), "Expected one *" + suffix + " file in " + ...
        fullfile(source, "MAData", trialName))
    copyfile(fullfile(file.folder, file.name), ...
        fullfile(target, "MAData", trialName));
end
fprintf("Copied %d surrogate data files to %s\n", ...
    length(suffixes) + 1, target);
end
