% This function starts (or reuses) the process-based parallel pool used by
% the tools' optimizers (UseParallel) before a test moves into a
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
% OpenSim's Java objects and pctRunOnAll need process workers, so a
% thread-based pool (e.g. from a "Threads" default profile) is replaced.
pool = gcp("nocreate");
if ~isempty(pool) && ~isa(pool, "parallel.ProcessPool")
    delete(pool);
    pool = [];
end
if isempty(pool)
    parpool("Processes");
end
pctRunOnAll org.opensim.modeling.Logger.removeFileSink();
end
