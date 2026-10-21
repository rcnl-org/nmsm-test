% Tests for the functions JMP uses to change one model parameter at a time
% (src/JointModelPersonalization/KinematicCalibration/functions/adjust*).
% Each test sets one value on a fresh simple_arm model and checks that
% exactly that value changed and nothing else did.

classdef (TestTags = {'Unit'}) AdjustFunctionsTest < matlab.unittest.TestCase

    properties (Constant)
        jointName = 'r_elbow'
        newValue = 0.123 % differs from every existing frame value
    end

    properties
        model
    end

    properties (TestParameter)
        % Row of jmpFrameValues() each adjust function changes.
        frameParameter = struct( ...
            "parentTranslation", struct("fn", @adjustParentTranslation, "row", 1), ...
            "parentOrientation", struct("fn", @adjustParentOrientation, "row", 2), ...
            "childTranslation", struct("fn", @adjustChildTranslation, "row", 3), ...
            "childOrientation", struct("fn", @adjustChildOrientation, "row", 4))
        axis = {0, 1, 2}
        markerAxis = {"x", "y", "z"}
    end

    methods (TestMethodSetup)
        function loadFreshModel(testCase)
            testCase.model = Model(testDataPath("jmp", "simple_arm.osim"));
        end
    end

    methods (Test)
        function adjustFrameChangesOnlyThatValue(testCase, frameParameter, ...
                axis)
            before = jmpFrameValues(testCase.model, testCase.jointName);
            frameParameter.fn(testCase.model, testCase.jointName, axis, ...
                testCase.newValue);
            after = jmpFrameValues(testCase.model, testCase.jointName);

            expected = before;
            expected(frameParameter.row, axis + 1) = testCase.newValue;
            testCase.verifyEqual(after, expected, "AbsTol", 1e-12);
        end

        function adjustMarkerPositionChangesOnlyThatAxis(testCase, ...
                markerAxis)
            before = markerLocations(testCase.model);
            adjustMarkerPosition(testCase.model, 'r_radius1', ...
                testCase.newValue, markerAxis);
            after = markerLocations(testCase.model);

            expected = before;
            expected(markerNames() == "r_radius1", ...
                markerAxis == ["x", "y", "z"]) = testCase.newValue;
            testCase.verifyEqual(after, expected, "AbsTol", 1e-12);
        end

        % adjustBodyScaling's last argument is <anatomical_markers>, which
        % is not a setting the pipeline uses. These tests pass false, the
        % value the parser gives when the element is absent.

        function adjustBodyScalingSetsScaleFactor(testCase)
            adjustBodyScaling(testCase.model, 'r_ulna_radius_hand', 1.1, false);
            testCase.verifyEqual(getScalingParameterValue(testCase.model, ...
                'r_ulna_radius_hand'), 1.1, "AbsTol", 1e-12);
            testCase.verifyEqual(getScalingParameterValue(testCase.model, ...
                'r_humerus'), 1, "AbsTol", 1e-12);
        end

        function adjustBodyScalingIsAbsoluteNotCumulative(testCase)
            % The optimizer passes absolute scale values, so scaling to
            % 1.1 and then to 1.2 must give 1.2, not 1.1 * 1.2.
            adjustBodyScaling(testCase.model, 'r_ulna_radius_hand', 1.1, false);
            adjustBodyScaling(testCase.model, 'r_ulna_radius_hand', 1.2, false);
            testCase.verifyEqual(getScalingParameterValue(testCase.model, ...
                'r_ulna_radius_hand'), 1.2, "AbsTol", 1e-12);
        end

        function adjustBodyScalingKeepsMarkerLocations(testCase)
            % Markers keep their location in the body frame when the body
            % is scaled; marker positions are adjusted separately.
            before = markerLocations(testCase.model);
            adjustBodyScaling(testCase.model, 'r_ulna_radius_hand', 1.1, false);
            testCase.verifyEqual(markerLocations(testCase.model), before, ...
                "AbsTol", 1e-9);
        end
    end
end

function locations = markerLocations(model)
% One row per marker in markerNames() order: [x y z] in its body frame.
names = markerNames();
locations = zeros(length(names), 3);
for i = 1:length(names)
    location = model.getMarkerSet().get(char(names(i))).get_location();
    locations(i, :) = [location.get(0), location.get(1), location.get(2)];
end
end

function names = markerNames()
names = ["r_humerus1", "r_humerus2", "r_humerus3", ...
    "r_radius1", "r_radius2", "r_radius3"];
end
