function map = createMap(params)
%CREATEMAP Build a simple 3D urban environment.

map.xlim = params.map.xlim;
map.ylim = params.map.ylim;
map.zlim = params.map.zlim;

% Axis-aligned box obstacles: [xmin xmax ymin ymax zmin zmax]
map.obstacles = [
    18 30 16 34  0 28;
    38 52 48 62  0 32;
    60 72 20 36  0 26;
    26 40 66 82  0 30;
    72 84 68 86  0 34;
    48 58 12 24  0 22
];

% No-fly zones as vertical cylinders: [cx cy radius zmin zmax]
map.nfz = [
    44 30  8  0 40;
    68 52 10  0 42;
    24 56  7  0 40
];

% Wind-risk hot spots: [cx cy cz sigma amp]
map.windHotspots = [
    35 40 24 12 0.9;
    58 72 22 10 1.2;
    76 42 18 14 0.8
];

% Prevailing wind (used in simplified energy model)
map.baseWind = [2.5, 1.2, 0.0];
end