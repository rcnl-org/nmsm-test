% This function returns all twelve frame parameters of a joint as a 4x3
% matrix, so tests can check that exactly one of them changed.
% Rows: parent translation, parent orientation, child translation, child
% orientation. Columns: x, y, z.
%
% (Model, string) -> (4x3 double)

function values = jmpFrameValues(model, jointName)
flags = [true true; true false; false true; false false];
values = zeros(4, 3);
for row = 1:4
    for axis = 0:2
        values(row, axis + 1) = getFrameParameterValue(model, jointName, ...
            flags(row, 1), flags(row, 2), axis);
    end
end
end
