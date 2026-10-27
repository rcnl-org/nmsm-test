% This function is part of the NMSM Pipeline, see file for full license.
%
% This function runs the NMSM Pipeline test suite in tests/ against an
% nmsm-core checkout. Tests are grouped into tiers by their TestTags:
% "Unit" (fast, isolated functions), "Parsing" (settings file ->
% inputs/params structs), and "Regression" (full tool runs compared against
% stored nominal results).
%
% The suite tests whatever branch nmsm-core currently has checked out. By
% default nmsm-core is expected next to this repo (../nmsm-core); its
% project is opened if it is not already open, and its branch and commit
% are printed so results can be matched to the code they tested.
%
% Examples:
%   runTests()                                  % Unit tests only (default)
%   runTests("parsing")                         % one tier
%   runTests("all")                             % every tier
%   runTests("unit", Coverage=true)             % with HTML coverage report
%   runTests("unit", CorePath="D:\nmsm-core")   % nmsm-core somewhere else
%   runTests("all", Tool="GCP")                 % one tool's tests, every tier
%   runTests("regression", Tool=["MTP", "NCP"]) % several tools, one tier
%
% Tool is any of "JMP", "MTP", "MTLI", "NCP", "GCP", "Tracking",
% "Verification", "Design" (the three Treatment Optimization tools), "TO"
% (all of Treatment Optimization: its shared tests and all three tools)
% and "core" (the tests of shared src/core code in tests/unit/core), in any
% case. A tool's tests are those in its tests/unit/<tool name> folder and
% the parsing and regression test classes named after it.
%
% (string, logical, string, string) -> (matlab.unittest.TestResult)

% ----------------------------------------------------------------------- %
% The NMSM Pipeline is a toolkit for model personalization and treatment  %
% optimization of neuromusculoskeletal models through OpenSim. See        %
% nmsm.rice.edu and the NOTICE file for more information. The             %
% NMSM Pipeline is developed at Rice University and supported by the US   %
% National Institutes of Health (R01 EB030520).                           %
%                                                                         %
% Copyright (c) 2021 Rice University and the Authors                      %
%                                                                         %
% Licensed under the Apache License, Version 2.0 (the "License");         %
% you may not use this file except in compliance with the License.        %
% You may obtain a copy of the License at                                 %
% http://www.apache.org/licenses/LICENSE-2.0.                             %
%                                                                         %
% Unless required by applicable law or agreed to in writing, software     %
% distributed under the License is distributed on an "AS IS" BASIS,       %
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or         %
% implied. See the License for the specific language governing            %
% permissions and limitations under the License.                          %
% ----------------------------------------------------------------------- %

function results = runTests(tier, options)
arguments
    tier (1, 1) string {mustBeMember(tier, ...
        ["unit", "parsing", "regression", "all"])} = "unit"
    options.Coverage (1, 1) logical = false
    options.CorePath (1, 1) string = fullfile( ...
        fileparts(mfilename("fullpath")), "..", "nmsm-core")
    options.Tool (1, :) string {mustBeTool} = "all"
end
import matlab.unittest.TestRunner
import matlab.unittest.TestSuite
import matlab.unittest.selectors.HasTag
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageReport

repositoryDirectory = fileparts(mfilename("fullpath"));
testsDirectory = fullfile(repositoryDirectory, "tests");
corePath = getCanonicalPath(options.CorePath);

originalFolder = pwd;
restoreFolder = onCleanup(@() cd(originalFolder));
% Folders of other nmsm-core checkouts (e.g. saved in pathdef.m) would let
% the tests call code from the wrong branch, so they are taken off the
% path for the run and put back at the end.
removedFolders = removeOtherCoreFolders(corePath);
openCoreProject(corePath);
verifyProjectOpened()
printCoreVersion(corePath);

% One cleanup, so the removed folders are added after the path is
% restored rather than in an undefined order.
originalPath = path;
restorePath = onCleanup(@() restoreTestPath(originalPath, removedFolders));
addpath(fullfile(testsDirectory, "helpers"));

% Hide OpenSim info/warning output (e.g. missing .vtp geometry) so the
% test report stays readable; restore the previous level afterwards.
originalLogLevel = string(org.opensim.modeling.Logger.getLevelString());
org.opensim.modeling.Logger.setLevelString("error");
restoreLogLevel = onCleanup(@() ...
    org.opensim.modeling.Logger.setLevelString(originalLogLevel));

% Stop on a test file that cannot be loaded (e.g. a syntax error) instead of
% silently skipping it, which would look like a passing run.
suite = TestSuite.fromFolder(testsDirectory, "IncludingSubfolders", true, ...
    "InvalidFileFoundAction", "error");
if tier ~= "all"
    tag = upper(extractBefore(tier, 2)) + lower(extractAfter(tier, 1));
    suite = suite.selectIf(HasTag(tag));
end
if ~any(lower(options.Tool) == "all")
    suite = selectTools(suite, options.Tool, testsDirectory);
    fprintf("Tools: %s\n", strjoin(options.Tool, ", "));
end

runner = TestRunner.withTextOutput;
if options.Coverage
    % The nmsm-core folders the suite tests. Add a tool's folder here when
    % its tests are added, so the report shows what is still untested.
    coveredFolders = fullfile(corePath, "src", ["JointModelPersonalization", ...
        "MuscleTendonPersonalization", "MuscleTendonLengthInitialization", ...
        "NeuralControlPersonalization", "GroundContactPersonalization", ...
        "TreatmentOptimization", fullfile("core", "optimal_control"), ...
        fullfile("core", "muscle"), ...
        fullfile("core", "synergies"), fullfile("core", "BSpline")]);
    coverageFolder = fullfile(tempdir, "nmsmTestCoverage");
    runner.addPlugin(CodeCoveragePlugin.forFolder(coveredFolders, ...
        "IncludingSubfolders", true, ...
        "Producing", CoverageReport(coverageFolder)));
    fprintf("Coverage report: %s\n", fullfile(coverageFolder, "index.html"));
end

results = runner.run(suite);
disp(table(results))
end

% (string) -> (None)
% Opens the nmsm-core project unless it is already the open project.
function openCoreProject(corePath)
assert(isfile(fullfile(corePath, "Project.prj")), "No nmsm-core " + ...
    "project found at " + corePath + ". Pass CorePath=... to runTests.")
try
    openRoot = getCanonicalPath(currentProject().RootFolder);
catch
    openRoot = "";
end
if openRoot ~= corePath
    openProject(fullfile(corePath, "Project.prj"));
end
end

% (string) -> (string array)
% Removes path folders that belong to an nmsm-core checkout other than the
% one under test, and returns them. A folder belongs to a checkout if it is
% inside a folder holding Project.prj. If the project at corePath is not
% open yet, its own folders are removed too, because openProject refuses
% to open a project whose folders are already on the path.
function removed = removeOtherCoreFolders(corePath)
try
    openRoot = getCanonicalPath(currentProject().RootFolder);
catch
    openRoot = "";
end
folders = string(strsplit(path, pathsep));
removed = strings(1, 0);
for folder = folders(contains(folders, filesep + "src"))
    root = extractBefore(folder, filesep + "src");
    if ~isfile(fullfile(root, "Project.prj"))
        continue
    end
    root = getCanonicalPath(root);
    if root ~= corePath || openRoot ~= corePath
        removed(end + 1) = folder; %#ok<AGROW>
    end
end
if ~isempty(removed)
    rmpath(removed{:});
end
end

% (char, string array) -> (None)
% Restores the path from before the tests, then puts the folders removed
% by removeOtherCoreFolders back at the end, unless already on it.
function restoreTestPath(originalPath, folders)
path(originalPath);
folders = folders(~ismember(folders, string(strsplit(path, pathsep))));
if ~isempty(folders)
    addpath(folders{:}, "-end");
end
end

% (string) -> (None)
% Prints the nmsm-core branch and commit under test.
function printCoreVersion(corePath)
[branchStatus, branch] = system(sprintf( ...
    'git -C "%s" rev-parse --abbrev-ref HEAD', corePath));
[commitStatus, commit] = system(sprintf( ...
    'git -C "%s" log -1 --format="%%h %%ad" --date=short', corePath));
if branchStatus == 0 && commitStatus == 0
    fprintf("Testing nmsm-core at %s: %s (%s)\n", corePath, ...
        strtrim(branch), strtrim(commit));
else
    fprintf("Testing nmsm-core at %s (git branch unavailable)\n", corePath);
end
end

% (string) -> (string)
% Resolves "..", relative paths, and trailing separators.
function canonicalPath = getCanonicalPath(folder)
canonicalPath = string(java.io.File(char(folder)).getCanonicalPath());
end

% (matlab.unittest.Test, string array, string) -> (matlab.unittest.Test)
% Keeps the tests of the given tools: those in tests/unit/<tool name> (and
% its subfolders) and the parsing and regression test classes whose names
% start with the tool name.
function suite = selectTools(suite, tools, testsDirectory)
baseFolders = string({suite.BaseFolder});
classNames = string({suite.TestParentName});
keep = false(size(suite));
for tool = toolFolderNames(tools)
    unitFolder = fullfile(testsDirectory, "unit", tool);
    inUnitFolder = baseFolders == unitFolder | ...
        startsWith(baseFolders, unitFolder + filesep);
    namedForTool = startsWith(classNames, tool) & ...
        endsWith(classNames, ["ParsingTest", "RegressionTest"]);
    keep = keep | inUnitFolder | namedForTool;
end
suite = suite(keep);
assert(~isempty(suite), "No tests found for " + strjoin(tools, ", ") + ...
    " in this tier.")
end

% (string array) -> (string array)
% The folder and class name prefix used for each tool's tests.
function names = toolFolderNames(tools)
table = toolTable();
names = strings(1, 0);
for tool = upper(tools)
    names = [names, table.(tool)]; %#ok<AGROW>
end
names = unique(names, "stable");
end

% () -> (struct)
% Each Tool name (upper case) and the folder and class name prefixes of its
% tests. "TO" is the shared Treatment Optimization tests and all three
% Treatment Optimization tools.
function table = toolTable()
table.JMP = "JointModelPersonalization";
table.MTP = "MuscleTendonPersonalization";
table.MTLI = "MuscleTendonLengthInitialization";
table.NCP = "NeuralControlPersonalization";
table.GCP = "GroundContactPersonalization";
table.TRACKING = "TrackingOptimization";
table.VERIFICATION = "VerificationOptimization";
table.DESIGN = "DesignOptimization";
table.TO = ["TreatmentOptimization", table.TRACKING, ...
    table.VERIFICATION, table.DESIGN];
table.CORE = "core";
end

% (string array) -> (None)
% Validates Tool: "all" or any of the names in toolTable, in any case.
function mustBeTool(tools)
valid = ["ALL", string(fieldnames(toolTable()))'];
if ~all(ismember(upper(tools), valid))
    error("Tool must be ""all"" or any of ""JMP"", ""MTP"", ""MTLI"", " + ...
        """NCP"", ""GCP"", ""TO"", ""Tracking"", ""Verification"", " + ...
        """Design"" and ""core"".")
end
end
