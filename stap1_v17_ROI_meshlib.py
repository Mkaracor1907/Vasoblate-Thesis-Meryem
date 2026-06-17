"""
=============================================================
  STAP 1 v17 — ROI-crop (MeshLib) + wall offset + boolean subtract
  Geen manifold3d nodig: crop gebeurt met MeshLib (mm.boolean),
  dezelfde functie die je v15-notebook al gebruikt.

  INPUT  (D:\\Meryem Thesis\\STL_files):
    01_arteries_reference_for_COMSOL.stl
    02_pancreas_aligned_to_arteries_for_COMSOL.stl

  OUTPUT (zelfde map):
    tmp_lumen.stl
    tmp_wall_outer.stl
    tmp_pancreas_holes.stl

  Daarna: MATLAB stap2_tetgen_pig197_v8.m
=============================================================
"""

import meshlib.mrmeshpy as mm
import trimesh
import numpy as np
import os

folder = r"D:\Meryem Thesis\STL_files"

lumen_path    = os.path.join(folder, "01_arteries_reference_for_COMSOL.stl")
pancreas_path = os.path.join(folder, "02_pancreas_aligned_to_arteries_for_COMSOL.stl")

# ============================================================
# ROI-BOX (mm) - bepaalt welk deel je HOUDT
#   x: -8..56  (AORTA-HOOFDSTAM + splenic naar rechts; linkertakken eraf)
#              de aorta-stam zit in x[-8,8], linkertakken in x<-8
#   z: -50..35 (ruim stuk aorta rond de splenic-aftakking)
#   y: ruim (diepte volledig)
# Diffuser zit op [27.22, 9.96, -15.80] -> binnen deze box.
# Pas grenzen hieronder aan als je meer/minder aorta wilt.
# ============================================================
# Aparte grenzen voor arterie en pancreas:
#  - Arterie: x=-7 (aorta-stam + splenic; linkertakken eraf)
#  - Pancreas: x=2 (begint waar splenic-pancreas contact begint; weefsel
#                   links daarvan raakt de splenic artery niet en mag weg)
ART_XMIN, ART_XMAX = -7.0, 56.0     # arterie/lumen crop
PAN_XMIN, PAN_XMAX =  2.0, 56.0     # pancreas crop (vanaf contactgebied)
ROI_ZMIN, ROI_ZMAX = -55.0, 50.0    # zelfde z voor beide (ruime aorta-lengte)
ROI_YMIN, ROI_YMAX = -40.0, 50.0    # ruim, dekt de volledige diepte

WALL_OFFSET     = 1.3
SUBTRACT_OFFSET = 1.7
SMOOTH_ITERS    = 3


# ============================================================
# HELPER: maak een MeshLib box-mesh van min/max hoekpunten
# ============================================================
def make_box_mesh(xmin, xmax, ymin, ymax, zmin, zmax):
    """Bouw een gesloten box als MeshLib-mesh via 8 hoekpunten + 12 driehoeken."""
    # 8 hoekpunten
    verts = np.array([
        [xmin, ymin, zmin],  # 0
        [xmax, ymin, zmin],  # 1
        [xmax, ymax, zmin],  # 2
        [xmin, ymax, zmin],  # 3
        [xmin, ymin, zmax],  # 4
        [xmax, ymin, zmax],  # 5
        [xmax, ymax, zmax],  # 6
        [xmin, ymax, zmax],  # 7
    ], dtype=float)
    # 12 driehoeken (buitennormaal), consistente winding
    faces = np.array([
        [0,2,1],[0,3,2],   # bottom (z=zmin)
        [4,5,6],[4,6,7],   # top    (z=zmax)
        [0,1,5],[0,5,4],   # front  (y=ymin)
        [2,3,7],[2,7,6],   # back   (y=ymax)
        [1,2,6],[1,6,5],   # right  (x=xmax)
        [0,4,7],[0,7,3],   # left   (x=xmin)
    ], dtype=np.int32)
    # bouw via trimesh -> export -> MeshLib inladen (robuust, versie-onafhankelijk)
    box_tri = trimesh.Trimesh(vertices=verts, faces=faces, process=True)
    box_path = os.path.join(folder, "_roi_box.stl")
    box_tri.export(box_path)
    box_mm = mm.loadMesh(str(box_path))
    os.remove(box_path)
    return box_mm


def crop_meshlib(mesh_mm, box_mm):
    """ROI-crop = intersectie van mesh met box (MeshLib boolean)."""
    res = mm.boolean(mesh_mm, box_mm, mm.BooleanOperation.Intersection)
    return res.mesh


# ============================================================
# 1. LADEN (MeshLib)
# ============================================================
print("[1/7] Meshes laden...")
lumen    = mm.loadMesh(str(lumen_path))
pancreas = mm.loadMesh(str(pancreas_path))
print(f"      Lumen:    {lumen.topology.numValidFaces()} triangles")
print(f"      Pancreas: {pancreas.topology.numValidFaces()} triangles")

# ============================================================
# 2. ROI-CROP (beide, zelfde box) via MeshLib
# ============================================================
print("[2/7] ROI-crop (MeshLib, aparte grenzen)...")
box_art = make_box_mesh(ART_XMIN, ART_XMAX, ROI_YMIN, ROI_YMAX, ROI_ZMIN, ROI_ZMAX)
box_pan = make_box_mesh(PAN_XMIN, PAN_XMAX, ROI_YMIN, ROI_YMAX, ROI_ZMIN, ROI_ZMAX)
lumen    = crop_meshlib(lumen,    box_art)
pancreas = crop_meshlib(pancreas, box_pan)
print(f"      Lumen ROI (x>={ART_XMIN}):    {lumen.topology.numValidFaces()} triangles")
print(f"      Pancreas ROI (x>={PAN_XMIN}): {pancreas.topology.numValidFaces()} triangles")

dif = (27.22, 9.96, -15.80)
in_roi = (ART_XMIN<=dif[0]<=ART_XMAX) and (ROI_ZMIN<=dif[2]<=ROI_ZMAX)
print(f"      Diffuser binnen arterie-ROI: {in_roi}")

# ============================================================
# 3. SMOOTHEN
# ============================================================
print("[3/7] Smoothen...")
relax = mm.MeshRelaxParams(); relax.iterations = SMOOTH_ITERS
mm.relax(lumen, relax)
mm.relax(pancreas, relax)
print("      OK")

# ============================================================
# 4. WALL OFFSET 1.3 mm
# ============================================================
print(f"[4/7] Artery wall offset {WALL_OFFSET} mm...")
params = mm.OffsetParameters()
params.voxelSize = lumen.computeBoundingBox().diagonal() * 5e-3
if mm.findRightBoundary(lumen.topology).empty():
    params.signDetectionMode = mm.SignDetectionMode.HoleWindingRule
wall_outer = mm.offsetMesh(lumen, WALL_OFFSET, params)
print(f"      OK — {wall_outer.topology.numValidFaces()} triangles")

# ============================================================
# 5. SUBTRACT-OFFSET 1.7 mm (1.3 + 0.4 gap)
# ============================================================
print(f"[5/7] Subtract offset {SUBTRACT_OFFSET} mm (gap)...")
params2 = mm.OffsetParameters()
params2.voxelSize = lumen.computeBoundingBox().diagonal() * 5e-3
if mm.findRightBoundary(lumen.topology).empty():
    params2.signDetectionMode = mm.SignDetectionMode.HoleWindingRule
wall_for_subtract = mm.offsetMesh(lumen, SUBTRACT_OFFSET, params2)
print(f"      OK — {wall_for_subtract.topology.numValidFaces()} triangles")

# ============================================================
# 6. BOOLEAN SUBTRACT (pancreas MINUS wall_for_subtract) + grootste comp.
# ============================================================
print("[6/7] Boolean subtract + grootste component...")
relax2 = mm.MeshRelaxParams(); relax2.iterations = 5
result = mm.boolean(pancreas, wall_for_subtract, mm.BooleanOperation.DifferenceAB)
mm.relax(result.mesh, relax2)

tmp = os.path.join(folder, "_tmp_pan_raw.stl")
mm.saveMesh(result.mesh, str(tmp))
mesh_tri = trimesh.load(tmp, force='mesh')
comps = sorted(mesh_tri.split(only_watertight=False),
               key=lambda m: m.faces.shape[0], reverse=True)
pancreas_clean = comps[0]
print(f"      OK — grootste component: {len(pancreas_clean.faces)} triangles")
os.remove(tmp)

# ============================================================
# 7. OPSLAAN
# ============================================================
print("[7/7] Opslaan...")
mm.saveMesh(lumen,      str(os.path.join(folder, "tmp_lumen.stl")))
mm.saveMesh(wall_outer, str(os.path.join(folder, "tmp_wall_outer.stl")))
pancreas_clean.export(os.path.join(folder, "tmp_pancreas_holes.stl"))

print()
print("=" * 55)
print("KLAAR — 3 bestanden aangemaakt (alleen ROI):")
print("  tmp_lumen.stl")
print("  tmp_wall_outer.stl")
print("  tmp_pancreas_holes.stl")
print()
print("Ga nu naar MATLAB: stap2_tetgen_pig197_v8.m")
print("=" * 55)
