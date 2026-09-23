"""
    Layer{T<:Real}

Abstract supertype of the concentric layers around a conductor or a group of cores.

Every layer defines:
- [`geometry`](@ref)
- [`inner_radius`](@ref)
- [`outer_radius`](@ref).

A [`TubularLayer`](@ref) ([`InsulationLayer`](@ref), [`SemiconLayer`](@ref),
[`TubularScreen`](@ref), [`Jacket`](@ref)) has an [`Annulus`](@ref) geometry. A
[`WireLayer`](@ref) ([`WireScreen`](@ref), [`Armour`](@ref)) has a [`WireGeometry`](@ref).
"""
abstract type Layer{T <: Real} end

"""
    TubularLayer{T<:Real} <: Layer{T}

Abstract supertype of layers whose [`geometry`](@ref) is an [`Annulus`](@ref).
"""
abstract type TubularLayer{T <: Real} <: Layer{T} end

"""
    WireLayer{T<:Real} <: Layer{T}

Abstract supertype of layers whose [`geometry`](@ref) is a [`WireGeometry`](@ref).
"""
abstract type WireLayer{T <: Real} <: Layer{T} end

"""
    InsulationLayer(r_in, r_out, material)
    InsulationLayer(geom::Annulus, material)

Main insulation between the conductor screen and the insulation screen. Radii in [m].
"""
struct InsulationLayer{T <: Real} <: TubularLayer{T}
    geom::Annulus{T}
    material::Material{T}
end

"""
    SemiconLayer(r_in, r_out, material = SEMICON)
    SemiconLayer(geom::Annulus, material = SEMICON)

Semiconducting screen on the conductor or on the insulation. Radii in [m].
"""
struct SemiconLayer{T <: Real} <: TubularLayer{T}
    geom::Annulus{T}
    material::Material{T}
end

"""
    TubularScreen(r_in, r_out, material)
    TubularScreen(geom::Annulus, material)

Solid metallic sheath or screen, e.g. an extruded lead or corrugated aluminium sheath.
Radii in [m].
"""
struct TubularScreen{T <: Real} <: TubularLayer{T}
    geom::Annulus{T}
    material::Material{T}
end

"""
    Jacket(r_in, r_out, material)
    Jacket(geom::Annulus, material)

Non-metallic outer sheath (serving) or bedding. Radii in [m].
"""
struct Jacket{T <: Real} <: TubularLayer{T}
    geom::Annulus{T}
    material::Material{T}
end

"""
    WireScreen(r_mean, n_wires, r_wire, lay_length, material)
    WireScreen(geom::WireGeometry, material)

Screen of `n_wires` round wires laid helically on a circle of radius `r_mean` [m]. Each wire
has radius `r_wire` [m]; `lay_length` [m] is the axial length of one full turn.
"""
struct WireScreen{T <: Real} <: WireLayer{T}
    geom::WireGeometry{T}
    material::Material{T}
end

"""
    Armour(r_mean, n_wires, r_wire, lay_length, material)
    Armour(geom::WireGeometry, material)

Armour of round wires, with the same geometry as [`WireScreen`](@ref). Use a material with
`mu_r > 1`, such as [`STEEL`](@ref), for magnetic armour.
"""
struct Armour{T <: Real} <: WireLayer{T}
    geom::WireGeometry{T}
    material::Material{T}
end

InsulationLayer(g::Annulus, m::Material) = InsulationLayer{_promote_numtype(g, m)}(g, m)
SemiconLayer(g::Annulus, m::Material = SEMICON) = SemiconLayer{_promote_numtype(g, m)}(g, m)
TubularScreen(g::Annulus, m::Material) = TubularScreen{_promote_numtype(g, m)}(g, m)
Jacket(g::Annulus, m::Material) = Jacket{_promote_numtype(g, m)}(g, m)
WireScreen(g::WireGeometry, m::Material) = WireScreen{_promote_numtype(g, m)}(g, m)
Armour(g::WireGeometry, m::Material) = Armour{_promote_numtype(g, m)}(g, m)

InsulationLayer(r_in::Real, r_out::Real, m::Material) = InsulationLayer(_annulus("InsulationLayer", r_in, r_out), m)
SemiconLayer(r_in::Real, r_out::Real, m::Material = SEMICON) = SemiconLayer(_annulus("SemiconLayer", r_in, r_out), m)
TubularScreen(r_in::Real, r_out::Real, m::Material) = TubularScreen(_annulus("TubularScreen", r_in, r_out), m)
Jacket(r_in::Real, r_out::Real, m::Material) = Jacket(_annulus("Jacket", r_in, r_out), m)

function WireScreen(r_mean::Real, n_wires::Integer, r_wire::Real, lay_length::Real, m::Material)
    return WireScreen(_wire_geometry("WireScreen", r_mean, n_wires, r_wire, lay_length), m)
end

function Armour(r_mean::Real, n_wires::Integer, r_wire::Real, lay_length::Real, m::Material)
    return Armour(_wire_geometry("Armour", r_mean, n_wires, r_wire, lay_length), m)
end

_retype(::Type{T}, l::InsulationLayer) where {T} = InsulationLayer{T}(l.geom, l.material)
_retype(::Type{T}, l::SemiconLayer) where {T} = SemiconLayer{T}(l.geom, l.material)
_retype(::Type{T}, l::TubularScreen) where {T} = TubularScreen{T}(l.geom, l.material)
_retype(::Type{T}, l::Jacket) where {T} = Jacket{T}(l.geom, l.material)
_retype(::Type{T}, l::WireScreen) where {T} = WireScreen{T}(l.geom, l.material)
_retype(::Type{T}, l::Armour) where {T} = Armour{T}(l.geom, l.material)

"""
    geometry(layer)

Cross-section of `layer`: an [`Annulus`](@ref) for a [`TubularLayer`](@ref), a
[`WireGeometry`](@ref) for a [`WireLayer`](@ref).
"""
function geometry end

geometry(l::Union{InsulationLayer, SemiconLayer, TubularScreen, Jacket, WireScreen, Armour}) = l.geom

inner_radius(l::Layer) = inner_radius(geometry(l))
outer_radius(l::Layer) = outer_radius(geometry(l))

numtype(::Layer{T}) where {T} = T

_is_metallic(::Layer) = false
_is_metallic(::Union{TubularScreen, WireLayer}) = true

function _check_stack(context, r_start, layers)
    r = r_start
    for (i, layer) in enumerate(layers)
        _fits_outside(inner_radius(layer), r) || throw(
            ArgumentError(
                "$context: layer $i ($(nameof(typeof(layer)))) starts at r = " *
                    "$(inner_radius(layer)) m, inside the radius $r m reached by what lies " *
                    "beneath it",
            ),
        )
        r = outer_radius(layer)
    end
    return nothing
end

const _Layers = Union{AbstractVector{<:Layer}, Tuple{Vararg{Layer}}}

_layers_numtype(::AbstractVector{<:Layer{T}}) where {T} = T
_layers_numtype(v::AbstractVector{<:Layer}) = _eltype_numtype(v)
_layers_numtype(t::Tuple{Vararg{Layer}}) = promote_type(Union{}, map(numtype, t)...)

_layer_vector(::Type{T}, layers) where {T} = Layer{T}[_retype(T, l) for l in layers]
