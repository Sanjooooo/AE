function f = cec_wrapper(x, funcId)
%CEC_WRAPPER Lightweight wrapper for CEC2017 MEX interface.
% Assumes current working directory is already the CEC folder.

x = x(:);   % enforce column vector
f = cec17_func(x, funcId);
end