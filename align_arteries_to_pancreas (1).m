%% align_arteries_to_pancreas.m
% Centreert de arterie op de pancreas en exporteert aligned STL's
% Output: 01_arteries_reference_for_COMSOL.stl
%         02_pancreas_aligned_to_arteries_for_COMSOL.stl

clear; clc; close all;

folder     = 'D:\Meryem Thesis\STL_files';
outputFolder = 'D:\Meryem Thesis\STL_files';

%% 1. Inladen
disp('[1/4] Inladen...');
artSTL = import_STL(fullfile(folder, '197Arteries.stl'));
panSTL = import_STL(fullfile(folder, '197Pancreas_remesh.stl'));

F_art = artSTL.solidFaces{1};   V_art = artSTL.solidVertices{1};
F_pan = panSTL.solidFaces{1};   V_pan = panSTL.solidVertices{1};

[F_art, V_art] = mergeVertices(F_art, V_art);
[F_pan, V_pan] = mergeVertices(F_pan, V_pan);

fprintf('    Arterie: %d vertices\n', size(V_art,1));
fprintf('    Pancreas: %d vertices\n', size(V_pan,1));
disp('    OK');

%% 2. Centroids berekenen
disp('[2/4] Centroids berekenen...');

% Gebruik bounding box middelpunt (robuuster dan mean voor lange structuren)
bbox_art = [min(V_art); max(V_art)];
bbox_pan = [min(V_pan); max(V_pan)];

center_art = mean(bbox_art, 1);
center_pan = mean(bbox_pan, 1);

fprintf('    Arterie centroid:  [%.1f %.1f %.1f]\n', center_art);
fprintf('    Pancreas centroid: [%.1f %.1f %.1f]\n', center_pan);

% Shift = verschil tussen centroids
shift = center_pan - center_art;
fprintf('    Shift arterie:     [%.1f %.1f %.1f]\n', shift);
disp('    OK');

%% 3. Arterie verschuiven naar pancreas coordinaten
disp('[3/4] Arterie alignen naar pancreas...');
V_art_aligned = V_art + shift;

% Verifieer
bbox_art_new = [min(V_art_aligned); max(V_art_aligned)];
center_art_new = mean(bbox_art_new, 1);
fprintf('    Arterie centroid na shift: [%.1f %.1f %.1f]\n', center_art_new);
fprintf('    Pancreas centroid:         [%.1f %.1f %.1f]\n', center_pan);
disp('    OK');

%% 4. Visualiseer voor controle
figure; hold on;
gpatch(F_pan, V_pan, [1.00 0.85 0.50], 'none', 0.25);
gpatch(F_art, V_art_aligned, [0.85 0.00 0.00], 'none', 0.80);
axis equal; grid on; view(3);
xlabel('x (mm)'); ylabel('y (mm)'); zlabel('z (mm)');
camlight headlight; lighting gouraud;
title('Controle alignment: pancreas + arterie');
legend({'Pancreas', 'Arterie (aligned)'}, 'Location', 'best');
rotate3d on;

%% 5. Exporteren
disp('[4/4] Exporteren...');

out_art = fullfile(outputFolder, '01_arteries_reference_for_COMSOL.stl');
out_pan = fullfile(outputFolder, '02_pancreas_aligned_to_arteries_for_COMSOL.stl');

patch2STL(out_art, V_art_aligned, F_art, [], '01_arteries_reference');
patch2STL(out_pan, V_pan,         F_pan, [], '02_pancreas_aligned');

disp(' ');
disp('==============================================');
disp('KLAAR:');
disp('  01_arteries_reference_for_COMSOL.stl');
disp('  02_pancreas_aligned_to_arteries_for_COMSOL.stl');
disp('Controleer de plot — arterie moet langs/door pancreas lopen');
disp('==============================================');
