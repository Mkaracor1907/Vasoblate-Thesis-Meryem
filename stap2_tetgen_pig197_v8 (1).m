%% stap2_tetgen_pig197_v8.m
% Geen centering - ITK-Snap coordinaten zijn al aligned
% Dit is de correcte aanpak

clear; clc; close all;

folder = 'D:\Meryem Thesis\STL_files';

%% 1. Inladen - GEEN centering, originele coordinaten gebruiken
disp('[1/5] Inladen (originele coordinaten)...');
lumenSTL    = import_STL(fullfile(folder, 'tmp_lumen.stl'));
wallSTL     = import_STL(fullfile(folder, 'tmp_wall_outer.stl'));
pancreasSTL = import_STL(fullfile(folder, 'tmp_pancreas_holes.stl'));

F_lum = lumenSTL.solidFaces{1};     V_lum = lumenSTL.solidVertices{1};
F_wal = wallSTL.solidFaces{1};      V_wal = wallSTL.solidVertices{1};
F_pan = pancreasSTL.solidFaces{1};  V_pan = pancreasSTL.solidVertices{1};

[F_lum, V_lum] = mergeVertices(F_lum, V_lum);
[F_wal, V_wal] = mergeVertices(F_wal, V_wal);
[F_pan, V_pan] = mergeVertices(F_pan, V_pan);

fprintf('    Lumen centroid:    [%.1f %.1f %.1f]\n', mean(V_lum));
fprintf('    Wall centroid:     [%.1f %.1f %.1f]\n', mean(V_wal));
fprintf('    Pancreas centroid: [%.1f %.1f %.1f]\n', mean(V_pan));
disp('    OK');

%% 2. Subtri + remesh zonder te centreren
disp('[2/5] Subtri verfijnen en remeshen...');
[F_lum, V_lum] = subtri(F_lum, V_lum, 1);
[F_wal, V_wal] = subtri(F_wal, V_wal, 1);
[F_pan, V_pan] = subtri(F_pan, V_pan, 1);

[F_lum, V_lum] = mergeVertices(F_lum, V_lum);
[F_wal, V_wal] = mergeVertices(F_wal, V_wal);
[F_pan, V_pan] = mergeVertices(F_pan, V_pan);

opt.pointSpacing = 0.9;
[F1, V1] = ggremesh(F_wal, V_wal, opt);  % wall
[F2, V2] = ggremesh(F_lum, V_lum, opt);  % lumen
[F3, V3] = ggremesh(F_pan, V_pan, opt);  % pancreas
disp('    OK');

%% 3. Region points exact zoals Kristie
disp('[3/5] Region points...');
[V_region1] = getInnerPoint({F1,F2},{V1,V2});  % wall
[V_region2] = getInnerPoint(F2,V2);             % lumen
[V_region3] = getInnerPoint(F3,V3);             % pancreas

V_regions = [V_region1; V_region2; V_region3];

fprintf('    Wall point:     [%.2f %.2f %.2f]\n', V_region1);
fprintf('    Lumen point:    [%.2f %.2f %.2f]\n', V_region2);
fprintf('    Pancreas point: [%.2f %.2f %.2f]\n', V_region3);
disp('    OK');

%% 4. TetGen
disp('[4/5] TetGen...');
[F,V,C] = joinElementSets({F1,F2,F3},{V1,V2,V3});

vol1 = tetVolMeanEst(F1,V1);
vol2 = tetVolMeanEst(F2,V2);
vol3 = tetVolMeanEst(F3,V3);

inputStruct.stringOpt          = '-pq1.2AaY';
inputStruct.Faces              = F;
inputStruct.Nodes              = V;
inputStruct.faceBoundaryMarker = C;
inputStruct.regionPoints       = V_regions;
inputStruct.regionA            = [vol1 vol2 vol3];

[meshOutput] = runTetGen(inputStruct);

if isempty(meshOutput.elements)
    error('TetGen gefaald');
end

E  = meshOutput.elements;
V  = meshOutput.nodes;
CE = meshOutput.elementMaterialID;
[uniqueCE,~,pid] = unique(CE);
[uCE,~,ic] = unique(CE);
counts = accumarray(ic,1);
T = table(uCE, counts, 'VariableNames', {'PID','Elementen'});
disp('    Elementen per domein:');
disp(T);
fprintf('    Domeinen: %d\n', numel(unique(CE)));
disp('    OK');

%% 5. NAS schrijven
disp('[5/5] NAS schrijven...');
outNAS = fullfile(folder, 'pig197_3domains.nas');
fid = fopen(outNAS, 'w');
for m = 1:size(V,1)
    fprintf(fid, '%-8s%-8s%-8s%8s%8s%8s\n', ...
        'GRID', num2str(m,'%6d'), '', ...
        num2str(V(m,1),'%9.2f'), ...
        num2str(V(m,2),'%8.2f'), ...
        num2str(V(m,3),'%8.2f'));
end
for m = 1:size(E,1)
    fprintf(fid, '%-8s%-8s%-8s%8s%8s%8s%8s\n', ...
        'CTETRA', num2str(m,'%6d'), num2str(pid(m),5), ...
        num2str(E(m,1),'%6d'), num2str(E(m,2),'%6d'), ...
        num2str(E(m,3),'%6d'), num2str(E(m,4),'%6d'));
end
fclose(fid);

info = dir(outNAS);
fprintf('\n    NAS: %.1f MB\n', info.bytes/1e6);
disp('==============================================');
disp('KLAAR: pig197_3domains.nas');
disp('PID 1 = artery wall');
disp('PID 2 = artery lumen');
disp('PID 3 = pancreas');
disp('==============================================');
