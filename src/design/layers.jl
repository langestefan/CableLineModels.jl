"""
    Layer{T<:Real}

Abstract supertype of the concentric layers around a conductor or a group of cores.

Every layer defines:
- [`inner_radius`](@ref)
- [`outer_radius`](@ref).

Tubular layers ([`InsulationLayer`](@ref), [`SemiconLayer`](@ref), [`TubularScreen`](@ref),
[`Jacket`](@ref)) store these radii directly.

Wire layers ([`WireScreen`](@ref), [`Armour`](@ref)) derive them from the mean radius
and the wire radius.
"""
abstract type Layer{T <: Real} end

for L in (:InsulationLayer, :SemiconLayer, :TubularScreen, :Jacket)
    @eval begin
        struct $L{T <: Real} <: Layer{T}
            r_in::T
            r_out::T
            material::Material{T}

            function $L{T}(r_in, r_out, material::Material) where {T <: Real}
                _check_finite($(string(L)), (; r_in, r_out))
                r_in > 0 && r_out - r_in > 0 || throw(
                    ArgumentError(
                        $(string(L)) *
                            ": need 0 < r_in < r_out, got r_in = $r_in, r_out = $r_out",
                    ),
                )
                return new{T}(r_in, r_out, material)
            end
        end

        function $L(r_in::Real, r_out::Real, material::Material)
            T = _promote_numtype(r_in, r_out, material)
            return $L{T}(r_in, r_out, material)
        end

        $L{T}(l::$L) where {T <: Real} = $L{T}(l.r_in, l.r_out, l.material)
        _retype(::Type{T}, l::$L) where {T} = $L{T}(l)
        inner_radius(l::$L) = l.r_in
        outer_radius(l::$L) = l.r_out
    end
end

"""
    InsulationLayer(r_in, r_out, material)

Main insulation between the conductor screen and the insulation screen. Radii in [m].
"""
InsulationLayer

"""
    SemiconLayer(r_in, r_out, material = SEMICON)

Semiconducting screen on the conductor or on the insulation. Radii in [m].
"""
SemiconLayer

SemiconLayer(r_in::Real, r_out::Real) = SemiconLayer(r_in, r_out, SEMICON)

"""
    TubularScreen(r_in, r_out, material)

Solid metallic sheath or screen, e.g. an extruded lead or corrugated aluminium sheath.
Radii in [m].
"""
TubularScreen

"""
    Jacket(r_in, r_out, material)

Non-metallic outer sheath (serving) or bedding. Radii in [m].
"""
Jacket

for L in (:WireScreen, :Armour)
    @eval begin
        struct $L{T <: Real} <: Layer{T}
            r_mean::T
            n_wires::Int
            r_wire::T
            lay_length::T
            material::Material{T}

            function $L{T}(
                    r_mean, n_wires::Integer, r_wire, lay_length, material::Material,
                ) where {T <: Real}
                _check_wires($(string(L)), r_mean, n_wires, r_wire, lay_length)
                return new{T}(r_mean, n_wires, r_wire, lay_length, material)
            end
        end

        function $L(
                r_mean::Real, n_wires::Integer, r_wire::Real, lay_length::Real,
                material::Material,
            )
            T = _promote_numtype(r_mean, r_wire, lay_length, material)
            return $L{T}(r_mean, n_wires, r_wire, lay_length, material)
        end

        function $L{T}(l::$L) where {T <: Real}
            return $L{T}(l.r_mean, l.n_wires, l.r_wire, l.lay_length, l.material)
        end
        _retype(::Type{T}, l::$L) where {T} = $L{T}(l)
        inner_radius(l::$L) = l.r_mean - l.r_wire
        outer_radius(l::$L) = l.r_mean + l.r_wire
    end
end

"""
    WireScreen(r_mean, n_wires, r_wire, lay_length, material)

Screen of `n_wires` round wires laid helically on a circle of radius `r_mean` [m]. Each wire
has radius `r_wire` [m]; `lay_length` [m] is the axial length of one full turn.
"""
WireScreen

"""
    Armour(r_mean, n_wires, r_wire, lay_length, material)

Armour of `n_wires` round wires, with the same geometry as [`WireScreen`](@ref). Use a
material with `mu_r > 1`, such as [`STEEL`](@ref), for magnetic armour.
"""
Armour

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

numtype(::Layer{T}) where {T} = T

_is_metallic(::Layer) = false
_is_metallic(::Union{TubularScreen, WireScreen, Armour}) = true

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
