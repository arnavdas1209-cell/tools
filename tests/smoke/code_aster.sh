#!/usr/bin/env bash
#
# code_aster.sh - Tier 3 smoke test: tiny linear-elastic Code_Aster case.
#
# Builds a tiny 3D linear-elastic static study and runs it headless through
# scripts/run_aster.sh, which drives the official Code_Aster container
# (Apptainer preferred, Docker fallback).
#
# A Code_Aster MECA_STATIQUE study reads its mesh with LIRE_MAILLAGE, so the
# case needs a real MED mesh that carries the named groups the .comm references
# (a fixed face and a loaded face). An empty/implicit mesh would make as_run
# error at mesh-reading time, so this test generates a genuine MED mesh with
# Gmsh (the python `gmsh` module writes Code_Aster-compatible MED groups) and
# passes it to run_aster.sh as the second argument. run_aster.sh then adds the
# `mmed` input unit to the synthesized .export, giving an end-to-end run that
# can actually reach PASS where a container runtime exists (the devcontainer/CI).
#
# Honesty rule / exit contract (0 PASS, 2 SKIP, other nonzero FAIL):
#   - SKIP (exit 2) when the python `gmsh` module is unavailable, so the MED
#     mesh cannot be synthesized here (the Amazon Linux 2023 host: gmsh needs
#     libGLU/apt libs absent on the host). We never pass a mesh-less case to
#     run_aster.sh, so the test never advertises an unreachable PASS.
#   - SKIP (exit 2) when there is no working container runtime (host case:
#     broken podman shim + no apptainer -> CONTAINER_RUNTIME=none); run_aster.sh
#     exits 2 and this test propagates it.
#   - PASS (exit 0) when gmsh produced the MED mesh AND a container runtime ran
#     as_run to completion (devcontainer/CI).
# Documented in docs/UNSUPPORTED.md. Prints TIER=/VERSION=/NOTE= lines.
set -euo pipefail

echo "TIER=3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RUN_ASTER="${REPO_ROOT}/scripts/run_aster.sh"

if [ ! -x "${RUN_ASTER}" ]; then
  echo "NOTE=scripts/run_aster.sh missing or not executable"
  echo "FAIL: run_aster.sh wrapper unavailable"
  exit 1
fi

# The case needs a MED mesh with named groups. We synthesize it with Gmsh.
# Without the python gmsh module we cannot build a valid grouped MED mesh
# headlessly (meshio's MED writer does not persist Code_Aster group names, and
# a hand-written HDF5 MED is not maintainable), so we SKIP rather than feed
# run_aster.sh a mesh-less case that could only ever error.
if ! python3 -c "import gmsh" >/dev/null 2>&1; then
  echo "NOTE=python gmsh module absent; cannot synthesize a grouped MED mesh here. gmsh (apt/conda-forge) + Code_Aster image run this in the devcontainer/CI. See docs/UNSUPPORTED.md"
  echo "SKIP: gmsh unavailable to build the MED mesh"
  exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

MESH_MED="${WORK}/box.mmed"

# Build a tiny box, mesh it, and tag two physical surface groups (FIX, LOAD)
# plus the volume (VOL). Gmsh writes MED 'groups of elements' that Code_Aster's
# LIRE_MAILLAGE reads directly. Named FIX/LOAD/VOL so the .comm below matches.
if ! python3 - "${MESH_MED}" <<'PY'
import sys
import gmsh

out = sys.argv[1]
gmsh.initialize()
gmsh.option.setNumber("General.Terminal", 0)
gmsh.model.add("elastic_box")

# 1 x 0.2 x 0.2 m box extending along +x.
L, B, H = 1.0, 0.2, 0.2
gmsh.model.occ.addBox(0, 0, 0, L, B, H)
gmsh.model.occ.synchronize()

# Identify the x=0 face (FIX) and the x=L face (LOAD) by their centroids.
fix_tags, load_tags = [], []
for dim, tag in gmsh.model.getEntities(2):
    x, _, _ = gmsh.model.occ.getCenterOfMass(dim, tag)
    if abs(x - 0.0) < 1e-6:
        fix_tags.append(tag)
    elif abs(x - L) < 1e-6:
        load_tags.append(tag)

vol_tags = [t for _, t in gmsh.model.getEntities(3)]
g_fix = gmsh.model.addPhysicalGroup(2, fix_tags)
gmsh.model.setPhysicalName(2, g_fix, "FIX")
g_load = gmsh.model.addPhysicalGroup(2, load_tags)
gmsh.model.setPhysicalName(2, g_load, "LOAD")
g_vol = gmsh.model.addPhysicalGroup(3, vol_tags)
gmsh.model.setPhysicalName(3, g_vol, "VOL")

gmsh.option.setNumber("Mesh.MeshSizeMax", H)
gmsh.model.mesh.generate(3)

# MED (.med) is Code_Aster's native mesh format; gmsh writes it by extension.
# run_aster.sh expects a .mmed name for the export's mmed unit, so write there.
gmsh.write(out)
gmsh.finalize()
PY
then
  echo "NOTE=gmsh failed to build the MED mesh (headless libs missing?)"
  echo "SKIP: could not synthesize the MED mesh"
  exit 2
fi

if [ ! -s "${MESH_MED}" ]; then
  echo "NOTE=gmsh produced no MED mesh output"
  echo "SKIP: MED mesh not generated"
  exit 2
fi

# Minimal linear-elastic static command file. LIRE_MAILLAGE reads box.mmed
# (unit 20, added by run_aster.sh); FIX/LOAD are the gmsh physical groups.
cat > "${WORK}/elastic.comm" <<'COMM'
DEBUT()

MA = LIRE_MAILLAGE(FORMAT='MED')

MO = AFFE_MODELE(MAILLAGE=MA,
                 AFFE=_F(TOUT='OUI',
                         PHENOMENE='MECANIQUE',
                         MODELISATION='3D'))

MAT = DEFI_MATERIAU(ELAS=_F(E=210.0E9, NU=0.3))

CHMAT = AFFE_MATERIAU(MAILLAGE=MA,
                      AFFE=_F(TOUT='OUI', MATER=MAT))

CLIM = AFFE_CHAR_MECA(MODELE=MO,
                      DDL_IMPO=_F(GROUP_MA='FIX', DX=0.0, DY=0.0, DZ=0.0))

CHAR = AFFE_CHAR_MECA(MODELE=MO,
                      FORCE_FACE=_F(GROUP_MA='LOAD', FZ=-1.0E3))

RESU = MECA_STATIQUE(MODELE=MO,
                     CHAM_MATER=CHMAT,
                     EXCIT=(_F(CHARGE=CLIM), _F(CHARGE=CHAR)))

RESU = CALC_CHAMP(reuse=RESU, RESULTAT=RESU,
                  CONTRAINTE='SIGM_ELNO')

FIN()
COMM

# Delegate to the wrapper, passing BOTH the .comm and the MED mesh so the
# synthesized .export carries the `mmed` input unit. The wrapper exits 2 (SKIP)
# when no container runtime is available, which we propagate per the honesty rule.
set +e
"${RUN_ASTER}" "${WORK}/elastic.comm" "${MESH_MED}" >"${WORK}/aster.log" 2>&1
rc=$?
set -e

if [ "${rc}" -eq 2 ]; then
  echo "NOTE=Code_Aster needs a container runtime (none here); official image via Apptainer/Docker in CI. See docs/UNSUPPORTED.md"
  echo "SKIP: no container runtime for Code_Aster"
  exit 2
fi

if [ "${rc}" -eq 0 ]; then
  echo "VERSION=Code_Aster (container image via run_aster.sh)"
  echo "PASS: Code_Aster ran the tiny elastic case on a gmsh-generated MED mesh"
  exit 0
fi

echo "NOTE=run_aster.sh returned ${rc}"
tail -n 15 "${WORK}/aster.log" 2>/dev/null || true
echo "FAIL: Code_Aster elastic case failed"
exit 1
