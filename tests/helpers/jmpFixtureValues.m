% This function returns the known values of the JMP test fixtures in
% tests/data/jmp, so tests share one source of truth instead of repeating
% numbers. JmpFixtureTest checks that the fixture files still match these.
%
% simple_arm.trc was generated from simple_arm.osim, so simple_arm.osim is
% the "truth": JMP started from either *_away model should move r_elbow's
% parent frame back to the values in values.truth.
%
% () -> (struct)

function values = jmpFixtureValues()
values.jointName = 'r_elbow';

% r_elbow parent frame in simple_arm.osim (x, y, z)
values.truth.parentTranslation = [0.0061, -0.2904, -0.0123]; % m
values.truth.parentOrientation = [0, 0, 0]; % rad

% simple_arm_translated_away.osim: parent x-translation moved +3 mm
values.translatedAway.parentTranslation = [0.0091, -0.2904, -0.0123];
values.translatedAway.parentOrientation = [0, 0, 0];

% simple_arm_oriented_away.osim: parent x-orientation rotated 0.5 rad
values.orientedAway.parentTranslation = [0.0061, -0.2904, -0.0123];
values.orientedAway.parentOrientation = [0.5, 0, 0];

values.markerNames = ["r_humerus1", "r_humerus2", "r_humerus3", ...
    "r_radius1", "r_radius2", "r_radius3"];
values.markerFileTimeRange = [0, 1.9833]; % s, 120 frames at 60 Hz
values.markerFileNumFrames = 120;
values.markerFileFrequency = 60; % Hz

% simple_arm_rounded_times.trc is simple_arm.trc with its times written to
% 5 decimals, as motion capture exports often write them. Adding 1/60 s to
% a rounded time can land past the next rounded time, which made JMP's IK
% skip the last frame.
values.roundedTimesDecimals = 5;
end
