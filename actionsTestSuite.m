% This script acts as the hook for running tests for the project. In this
% script, the project is loaded and all tests are run from the folder and
% any sub-folders of tests. At the end, assertSuccess() returns information
% regarding if the tests passed. This script was designed to work with
% GitHub Actions for CI/CD needs, it should not be modified without good
% reason.

% Copyright RCNL *change later*

matlab.project.loadProject(fullfile("..", "nmsm-core"));
cd(fullfile("nmsm-test"));
testResults = runtests('tests', 'IncludeSubfolders', true);

testResults.assertSuccess()