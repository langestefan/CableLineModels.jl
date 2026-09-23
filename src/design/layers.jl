"""
    Layer{T<:Real}

Abstract supertype of the concentric layers around a conductor or a group of cores.

Every layer defines:
- [`inner_radius`](@ref)
- [`outer_radius`](@ref).

A [`TubularLayer`](@ref) ([`InsulationLayer`](@ref), [`SemiconLayer`](@ref),
[`TubularScreen`](@ref), [`Jacket`](@ref)) stores these radii directly. A
[`WireLayer`](@ref) ([`WireScreen`](@ref), [`Armour`](@ref)) derives them from the mean
radius and the wire radius.
"""
abstract type Layer{T <: Real} end

"""
    TubularLayer{T<:Real} <: Layer{T}

Abstract supertype of layers bounded by two concentric cylinders. Subtypes have the fields
`r_in::T` and `r_out::T` [m] and `material::Material{T}`.
"""
abstract type TubularLayer{T <: Real} <: Layer{T} end

"""
    WireLayer{T<:Real} <: Layer{T}

Abstract supertype of layers of round wires laid helically on a circle. Subtypes have the
fields `r_mean::T` [m], `n_wires::Int`, `r_wire::T` [m], `lay_length::T` [m] and
`material::Material{T}`.
"""
abstract type WireLayer{T <: Real} <: Layer{T} end

"""
    InsulationLayer(r_in, r_out, material)

Main insulation between the conductor screen and the insulation screen. Radii in [m].
"""
struct InsulationLayer{T <: Real} <: TubularLayer{T}
    r_in::T
    r_out::T
    material::Material{T}

    function InsulationLayer{T}(r_in, r_out, material::Material) where {T <: Real}
        _check_tube("InsulationLayer", r_in, r_out)
        return new{T}(r_in, r_out, material)
    end
end

"""
    SemiconLayer(r_in, r_out, material = SEMICON)

Semiconducting screen on the conductor or on the insulation. Radii in [m].
"""
struct SemiconLayer{T <: Real} <: TubularLayer{T}
    r_in::T
    r_out::T
    material::Material{T}

    function SemiconLayer{T}(r_in, r_out, material::Material) where {T <: Real}
        _check_tube("SemiconLayer", r_in, r_out)
        return new{T}(r_in, r_out, material)
    end
end

"""
    TubularScreen(r_in, r_out, material)

Solid metallic sheath or screen, e.g. an extruded lead or corrugated aluminium sheath.
Radii in [m].
"""
struct TubularScreen{T <: Real} <: TubularLayer{T}
    r_in::T
    r_out::T
    material::Material{T}

    function TubularScreen{T}(r_in, r_out, material::Material) where {T <: Real}
        _check_tube("TubularScreen", r_in, r_out)
        return new{T}(r_in, r_out, material)
    end
end

"""
    Jacket(r_in, r_out, material)

Non-metallic outer sheath (serving) or bedding. Radii in [m].
"""
struct Jacket{T <: Real} <: TubularLayer{T}
    r_in::T
    r_out::T
    material::Material{T}

    function Jacket{T}(r_in, r_out, material::Material) where {T <: Real}
        _check_tube("Jacket", r_in, r_out)
        return new{T}(r_in, r_out, material)
    end
end

InsulationLayer(r_in::Real, r_out::Real, m::Material) = InsulationLayer{_promote_numtype(r_in, r_out, m)}(r_in, r_out, m)
SemiconLayer(r_in::Real, r_out::Real, m::Material = SEMICON) = SemiconLayer{_promote_numtype(r_in, r_out, m)}(r_in, r_out, m)
TubularScreen(r_in::Real, r_out::Real, m::Material) = TubularScreen{_promote_numtype(r_in, r_out, m)}(r_in, r_out, m)
Jacket(r_in::Real, r_out::Real, m::Material) = Jacket{_promote_numtype(r_in, r_out, m)}(r_in, r_out, m)

_retype(::Type{T}, l::InsulationLayer) where {T} = InsulationLayer{T}(l.r_in, l.r_out, l.material)
_retype(::Type{T}, l::SemiconLayer) where {T} = SemiconLayer{T}(l.r_in, l.r_out, l.material)
_retype(::Type{T}, l::TubularScreen) where {T} = TubularScreen{T}(l.r_in, l.r_out, l.material)
_retype(::Type{T}, l::Jacket) where {T} = Jacket{T}(l.r_in, l.r_out, l.material)

"""
    WireScreen(r_mean, n_wires, r_wire, lay_length, material)

Screen of `n_wires` round wires laid helically on a circle of radius `r_mean` [m]. Each wire
has radius `r_wire` [m]; `lay_length` [m] is the axial length of one full turn.
"""
struct WireScreen{T <: Real} <: WireLayer{T}
    r_mean::T
    n_wires::Int
    r_wire::T
    lay_length::T
    material::Material{T}

    function WireScreen{T}(
            r_mean, n_wires::Integer, r_wire, lay_length, material::Material,
        ) where {T <: Real}
        _check_wires("WireScreen", r_mean, n_wires, r_wire, lay_length)
        return new{T}(r_mean, n_wires, r_wire, lay_length, material)
    end
end

"""
    Armour(r_mean, n_wires, r_wire, lay_length, material)

Armour of `n_wires` round wires, with the same geometry as [`WireScreen`](@ref). Use a
material with `mu_r > 1`, such as [`STEEL`](@ref), for magnetic armour.
"""
struct Armour{T <: Real} <: WireLayer{T}
    r_mean::T
    n_wires::Int
    r_wire::T
    lay_length::T
    material::Material{T}

    function Armour{T}(
            r_mean, n_wires::Integer, r_wire, lay_length, material::Material,
        ) where {T <: Real}
        _check_wires("Armour", r_mean, n_wires, r_wire, lay_length)
        return new{T}(r_mean, n_wires, r_wire, lay_length, material)
    end
end

function WireScreen(r_mean::Real, n_wires::Integer, r_wire::Real, lay_length::Real, m::Material)
    T = _promote_numtype(r_mean, r_wire, lay_length, m)
    return WireScreen{T}(r_mean, n_wires, r_wire, lay_length, m)
end

function Armour(r_mean::Real, n_wires::Integer, r_wire::Real, lay_length::Real, m::Material)
    T = _promote_numtype(r_mean, r_wire, lay_length, m)
    return Armour{T}(r_mean, n_wires, r_wire, lay_length, m)
end

_retype(::Type{T}, l::WireScreen) where {T} = WireScreen{T}(l.r_mean, l.n_wires, l.r_wire, l.lay_length, l.material)
_retype(::Type{T}, l::Armour) where {T} = Armour{T}(l.r_mean, l.n_wires, l.r_wire, l.lay_length, l.material)

function _check_tube(context, r_in, r_out)
    _check_finite(context, (; r_in, r_out))
    r_in > 0 && r_out - r_in > 0 || throw(
        ArgumentError("$context: need 0 < r_in < r_out, got r_in = $r_in, r_out = $r_out"),
    )
    return nothing
end

function _check_wires(context, r_mean, n_wires, r_wire, lay_length)
    _check_finite(context, (; r_mean, r_wire, lay_length))
    n_wires >= 1 || throw(ArgumentError("$context: n_wires must be ≥ 1, got $n_wires"))
    r_wire > 0 && r_mean - r_wire > 0 || throw(
        ArgumentError(
            "$context: need 0 < r_wire < r_mean, got r_wire = $r_wire, r_mean = $r_mean",
        ),
    )
    lay_length > 0 ||
        throw(ArgumentError("$context: lay_length must be positive, got $lay_length"))
    n_wires == 1 || r_wire / r_mean <= sinpi(1 / n_wires) || throw(
        ArgumentError(
            "$context: $n_wires wires of radius $r_wire m do not fit on radius $r_mean m",
        ),
    )
    return nothing
end

"""
    inner_radius(x)

Inner radius of a layer or conductor [m].
"""
function inner_radius end

"""
    outer_radius(x)

Outer radius [m] of a layer, conductor, [`CableCore`](@ref) or [`CableDesign`](@ref).
"""
function outer_radius end

inner_radius(l::TubularLayer) = l.r_in
outer_radius(l::TubularLayer) = l.r_out
inner_radius(l::WireLayer) = l.r_mean - l.r_wire
outer_radius(l::WireLayer) = l.r_mean + l.r_wire

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
