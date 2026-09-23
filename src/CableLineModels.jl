"""
    CableLineModels

Electrical and thermal models of power cables and lines, computed from their physical design.
"""
module CableLineModels

export UnsupportedError
export Material, numtype
export COPPER, ALUMINIUM, LEAD, STEEL, XLPE, PVC, EPR, PAPER_OIL, MASS_IMPREGNATED, SEMICON

include("errors.jl")
include("materials/materials.jl")

end
