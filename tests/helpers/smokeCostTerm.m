% This function makes one enabled cost term of the given type for the term
% smoke tests, from a parsed term of the tool (template) so it has the
% fields the parser gives every term. An allowable error of 1 keeps the
% cost on the same scale for every term.
%
% (struct, string) -> (struct)

function term = smokeCostTerm(template, type)
term = template;
term.type = char(type);
term.isEnabled = true;
term.maxAllowableError = 1;
if ~isfield(term, "errorCenter") || ~isfinite(term.errorCenter)
    term.errorCenter = 0;
end
end
