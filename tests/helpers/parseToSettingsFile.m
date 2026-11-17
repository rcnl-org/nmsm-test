% This function parses a Treatment Optimization settings file in the
% current folder the way the tool named in it does
% (TrackingOptimizationTool, VerificationOptimizationTool or
% DesignOptimizationTool): xml2struct, verifyVersion, then that tool's
% parse<Tool>OptimizationSettingsTree. A file with no Treatment
% Optimization tool element is checked as a Tracking Optimization file.
%
% Example: [inputs, params] = parseToSettingsFile("settings_tracking_torque_minimal.xml")
%
% (string) -> (struct, struct)

function [inputs, params] = parseToSettingsFile(fileName)
tool = regexp(fileread(fileName), "<(Tracking|Verification|Design)" + ...
    "OptimizationTool[\s>]", "tokens", "once");
if isempty(tool)
    tool = "Tracking";
else
    tool = string(tool{1});
end
settingsTree = xml2struct(fileName);
verifyVersion(settingsTree, tool + "OptimizationTool");
parser = str2func("parse" + tool + "OptimizationSettingsTree");
[inputs, params] = parser(settingsTree);
end
