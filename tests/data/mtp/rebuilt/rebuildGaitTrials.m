% This function rebuilds tests/data/mtp/rebuilt/preprocessed: two gait
% trials (gait_1, 0.5 to 1.6 s, and gait_2, 1.6 to 2.7 s) from the raw
% data of the nmsm-tutorial data preprocessing step, using the tutorial's
% own settings. The tutorial's preprocessing script defines both trials,
% but only gait_1 was kept for its MTP step, and the IK, ID and muscle
% analysis results the script needs are not in the tutorial repository.
%
% It runs, in a temporary folder, with the MTP fixture model:
% 1. OpenSim Inverse Kinematics, Inverse Dynamics and Muscle Analysis from
%    input_data/IKSettings.xml, IDSettings.xml and MASettings.xml, over 0
%    to 4 s (the length of the raw EMG).
% 2. The tutorial's preprocessing.m steps: processRawEmgFile,
%    createMuscleTendonVelocity and splitIntoTrials with both time pairs.
%
% The result is not identical to tests/data/mtp/preprocessed (the
% tutorial's gait_1): EMG is normalized over these 4 s rather than the
% full 60 s recording, and IK and ID differ. Both rebuilt trials come from
% the same pipeline, which is what the two-trial synthetic case needs.
%
% Usage, with the nmsm-core project open and nmsm-tutorial next to
% nmsm-test, from the nmsm-test folder:
%   addpath("tests/data/mtp/rebuilt")
%   rebuildGaitTrials()
%
% (string) -> (None)

function rebuildGaitTrials(tutorialFolder)
arguments
    tutorialFolder (1, 1) string = fullfile(fileparts(fileparts( ...
        fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))))), ...
        "nmsm-tutorial")
end
verifyProjectOpened()
outputFolder = fileparts(mfilename("fullpath"));
modelFile = fullfile(fileparts(outputFolder), ...
    "UF_Subject_3_reduced_muscles.osim");
work = tempname;
mkdir(work);
originalFolder = cd(work);
cleanUp = onCleanup(@() leaveAndRemove(originalFolder, work));
% Otherwise OpenSim keeps opensim.log open in the folder to be removed.
org.opensim.modeling.Logger.removeFileSink();
copyfile(fullfile(tutorialFolder, "Step-3-Data-Preprocessing", ...
    "input_data"), "input_data");
copyfile(modelFile, "UF_Subject_3_reduced_muscles.osim");
modelFile = fullfile(work, "UF_Subject_3_reduced_muscles.osim");

cd("input_data");
ik = org.opensim.modeling.InverseKinematicsTool("IKSettings.xml");
ik.setModel(org.opensim.modeling.Model(modelFile));
ik.setMarkerDataFileName("GaitTrial48_markers.trc");
ik.setOutputMotionFileName("GaitTrial48_IKResults.mot");
ik.setStartTime(0);
ik.setEndTime(4);
ik.run();
id = org.opensim.modeling.InverseDynamicsTool("IDSettings.xml");
id.setModel(org.opensim.modeling.Model(modelFile));
id.setCoordinatesFileName("GaitTrial48_IKResults.mot");
id.setExternalLoadsFileName("ExternalForces.xml");
id.setResultsDir(".");
id.setOutputGenForceFileName("GaitTrial48_IDResults.sto");
id.setStartTime(0);
id.setEndTime(4);
id.run();
% AnalyzeTool only loads the motion when the model comes from its setup
% file, so the adjusted settings are written out and reloaded.
analyze = org.opensim.modeling.AnalyzeTool("MASettings.xml", false);
analyze.setModelFilename(modelFile);
analyze.setCoordinatesFileName("GaitTrial48_IKResults.mot");
analyze.setInitialTime(0);
analyze.setFinalTime(4);
analyze.setResultsDir("MuscleAnalysis");
analysis = analyze.getAnalysisSet().get(0);
analysis.setStartTime(0);
analysis.setEndTime(4);
analyze.print("MASettingsRun.xml");
org.opensim.modeling.AnalyzeTool("MASettingsRun.xml").run();
cd(work);

processRawEmgFile(fullfile("input_data", "GaitTrial48_EMG.mot"), 4, 40, ...
    3.5 / 1.1, fullfile("input_data", "GaitTrial48_EMG_Processed.mot"));
lengthFile = dir(fullfile("input_data", "MuscleAnalysis", ...
    "*_MuscleAnalysis_Length.sto"));
createMuscleTendonVelocity(fullfile(lengthFile.folder, lengthFile.name), 10);
inputSettings.rowsPerTrial = 101;
inputSettings.cutoffFrequency = 6;
inputSettings.model = "UF_Subject_3_reduced_muscles.osim";
inputSettings.ikFileName = fullfile("input_data", "GaitTrial48_IKResults.mot");
inputSettings.idFileName = fullfile("input_data", "GaitTrial48_IDResults.sto");
inputSettings.emgFileName = fullfile("input_data", ...
    "GaitTrial48_EMG_Processed.mot");
inputSettings.grfFileName = fullfile("input_data", "GaitTrial48_forces.mot");
inputSettings.maDirectory = fullfile("input_data", "MuscleAnalysis");
outputSettings.resultsDirectory = "preprocessed";
outputSettings.trialPrefix = "gait";
splitIntoTrials([0.5 1.6; 1.6 2.7], inputSettings, outputSettings);

target = fullfile(outputFolder, "preprocessed");
if isfolder(target)
    rmdir(target, "s");
end
mkdir(target);
for folder = ["EMGData", "IDData", "IKData", "MAData"]
    copyfile(fullfile("preprocessed", folder), fullfile(target, folder));
end
fprintf("Wrote %s\n", target);
end

function leaveAndRemove(originalFolder, folder)
cd(originalFolder);
rmdir(folder, "s");
end
