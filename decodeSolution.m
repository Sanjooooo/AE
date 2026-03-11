function ctrlPts = decodeSolution(X, params)
%DECODESOLUTION Convert row-vector decision variable to full control points.

inner = reshape(X, 3, []).';
ctrlPts = [params.start; inner; params.goal];
end