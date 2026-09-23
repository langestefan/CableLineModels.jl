"""
    CableLineModels

Electrical and thermal models of power cables and lines, computed from their physical design.
"""
module CableLineModels

export UnsupportedError
export Material
export COPPER, ALUMINIUM, LEAD, STEEL, XLPE, PVC, EPR, PAPER_OIL, MASS_IMPREGNATED, SEMICON
export ConductorShape, RoundSolid, RoundStranded, Milliken, Conductor
export Layer, TubularLayer, WireLayer, InsulationLayer, SemiconLayer, TubularScreen, WireScreen, Armour, Jacket
export CableCore, CoreLayout, SingleCore, FourCoreLV, CableDesign
export Annulus, WireGeometry, geometry, inner_radius, outer_radius, metallic_layers
export PlacedCable, Bonding, BothEnds, SinglePoint, CrossBonded, EarthModel, CableSystem
export ParameterMethod, IEC60287Method, LoopMethod, ZYData, compute_ZY

include("utils.jl")

"""
    UnsupportedError(msg, alternative = "")

Thrown when a valid input combination is not supported by the requested method.
"""
struct UnsupportedError <: Exception
    msg::String
    alternative::String
end

UnsupportedError(msg::AbstractString) = UnsupportedError(msg, "")

function Base.showerror(io::IO, e::UnsupportedError)
    print(io, "UnsupportedError: ", e.msg)
    isempty(e.alternative) || print(io, "\nAlternative: ", e.alternative)
    return nothing
end

include("materials/materials.jl")
include("design/shapes.jl")
include("design/geometry.jl")
include("design/layers.jl")
include("design/cable.jl")
include("design/system.jl")
include("parameters/interface.jl")
include("parameters/conductor.jl")
include("parameters/assembly.jl")

const _ValueTypes = Union{
    Material, Conductor, Annulus, WireGeometry, Layer, CableCore, FourCoreLV, CableDesign,
    PlacedCable, EarthModel, CableSystem, ZYData,
}

_fields(x) = ntuple(i -> getfield(x, i), Val(fieldcount(typeof(x))))
_same_kind(a, b) = nameof(typeof(a)) === nameof(typeof(b))

Base.:(==)(a::_ValueTypes, b::_ValueTypes) = _same_kind(a, b) && _fields(a) == _fields(b)
Base.isequal(a::_ValueTypes, b::_ValueTypes) = _same_kind(a, b) && isequal(_fields(a), _fields(b))
Base.hash(x::_ValueTypes, h::UInt) = hash(_fields(x), hash(nameof(typeof(x)), h))

end
