"""
    CableLineModels

Electrical and thermal models of power cables and lines, computed from their physical design.
"""
module CableLineModels

export UnsupportedError
export Material, numtype
export COPPER, ALUMINIUM, LEAD, STEEL, XLPE, PVC, EPR, PAPER_OIL, MASS_IMPREGNATED, SEMICON
export ConductorShape, RoundSolid, RoundStranded, Milliken, Conductor
export Layer, TubularLayer, WireLayer, InsulationLayer, SemiconLayer, TubularScreen, WireScreen, Armour, Jacket
export CableCore, CoreLayout, SingleCore, FourCoreLV, CableDesign
export Annulus, WireGeometry, geometry, inner_radius, outer_radius, metallic_layers
export PlacedCable, Installation, DirectBuried, InDuct, Bonding, BothEnds, SinglePoint, CrossBonded
export EarthModel, Compensation, CableSystem

include("utils.jl")
include("errors.jl")
include("materials/materials.jl")
include("design/shapes.jl")
include("design/geometry.jl")
include("design/layers.jl")
include("design/cable.jl")
include("design/system.jl")
include("equality.jl")

end
