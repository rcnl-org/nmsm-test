% This function starts (or reuses) the parallel pool used by JMP's
% optimizer (lsqnonlin with UseParallel) before a test moves into a
% temporary folder, and stops OpenSim from writing opensim.log on the
% client and workers.
%
% Without this, workers started from inside a temporary folder keep their
% opensim.log open there, and the folder cannot be deleted after the test.
% Note that this also turns off opensim.log in the calling MATLAB session.
%
% Does nothing if the Parallel Computing Toolbox is not installed, in which
% case JMP runs serially.
%
% () -> (None)

function startQuietParallelPool()
org.opensim.modeling.Logger.removeFileSink();
if isempty(ver("parallel")) || ~canUseParallelPool()
    return
end
originalFolder = cd(tempdir);
restoreFolder = onCleanup(@() cd(originalFolder));
gcp();
pctRunOnAll org.opensim.modeling.Logger.removeFileSink();
end
