"""
    CableLineModels

Electrical and thermal models of power cables and lines, computed from their physical design.
"""
module CableLineModels

export UnsupportedError
export Material, numtype
export COPPER, ALUMINIUM, LEAD, STEEL, XLPE, PVC, EPR, PAPER_OIL, MASS_IMPREGNATED, SEMICON
export ConductorShape, RoundSolid, RoundStranded, Milliken, Conductor
export Layer, InsulationLayer, SemiconLayer, TubularScreen, WireScreen, Armour, Jacket
export CableCore, CoreLayout, SingleCore, FourCoreLV, CableDesign
export inner_radius, outer_radius, metallic_layers

include("utils.jl")
include("errors.jl")
include("materials/materials.jl")
include("design/shapes.jl")
include("design/layers.jl")
include("design/cable.jl")
include("equality.jl")

end
