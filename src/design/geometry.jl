"""
    Annulus{T<:Real}

Cross-section between two concentric circles.

# Fields

  - `r_in::T`: inner radius [m].
  - `r_out::T`: outer radius [m].
"""
struct Annulus{T <: Real}
    r_in::T
    r_out::T

    function Annulus(r_in::Real, r_out::Real)
        _check_annulus("Annulus", r_in, r_out)
        values = _floats(r_in, r_out)
        return new{eltype(values)}(values...)
    end
end

"""
    WireGeometry{T<:Real}

Layer of round wires laid helically on a circle.

# Fields

  - `r_mean::T`: radius of the circle through the wire centres [m].
  - `n_wires::Int`
  - `r_wire::T`: wire radius [m].
  - `lay_length::T`: axial length of one full turn [m].
"""
struct WireGeometry{T <: Real}
    r_mean::T
    n_wires::Int
    r_wire::T
    lay_length::T

    function WireGeometry(r_mean::Real, n_wires::Integer, r_wire::Real, lay_length::Real)
        _check_wire_geometry("WireGeometry", r_mean, n_wires, r_wire, lay_length)
        r_mean, r_wire, lay_length = _floats(r_mean, r_wire, lay_length)
        return new{typeof(r_mean)}(r_mean, n_wires, r_wire, lay_length)
    end
end

"""
    inner_radius(x)

Inner radius [m] of a layer, its geometry, or a conductor.
"""
function inner_radius end

"""
    outer_radius(x)

Outer radius [m] of a layer, its geometry, a conductor, [`CableCore`](@ref) or
[`CableDesign`](@ref).
"""
function outer_radius end

inner_radius(g::Annulus) = g.r_in
outer_radius(g::Annulus) = g.r_out
inner_radius(g::WireGeometry) = g.r_mean - g.r_wire
outer_radius(g::WireGeometry) = g.r_mean + g.r_wire

function _check_annulus(context, r_in, r_out)
    _check_finite(context, (; r_in, r_out))
    r_in > 0 && r_out - r_in > 0 || throw(
        ArgumentError("$context: need 0 < r_in < r_out, got r_in = $r_in, r_out = $r_out"),
    )
    return nothing
end

function _check_wire_geometry(context, r_mean, n_wires, r_wire, lay_length)
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

function _annulus(context, r_in, r_out)
    _check_annulus(context, r_in, r_out)
    return Annulus(r_in, r_out)
end

function _wire_geometry(context, r_mean, n_wires, r_wire, lay_length)
    _check_wire_geometry(context, r_mean, n_wires, r_wire, lay_length)
    return WireGeometry(r_mean, n_wires, r_wire, lay_length)
end
