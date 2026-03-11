function X = encodeControlPoints(ctrlPts)
%ENCODECONTROLPOINTS Convert interior control points to a row vector.

inner = ctrlPts(2:end-1, :);
X = reshape(inner.', 1, []);
end