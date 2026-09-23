"""
    ConductorShape

Abstract supertype of conductor constructions. The shape selects the skin and proximity
effect coefficients; the geometry itself is given by the radii of the [`Conductor`](@ref).
"""
abstract type ConductorShape end

"""
    RoundSolid()

Solid round conductor.
"""
struct RoundSolid <: ConductorShape end

"""
    RoundStranded(n_wires)

Round stranded conductor made of `n_wires` wires.
"""
struct RoundStranded <: ConductorShape
    n_wires::Int

    function RoundStranded(n_wires::Integer)
        n_wires >= 1 || throw(ArgumentError("RoundStranded: n_wires must be ≥ 1, got $n_wires"))
        return new(n_wires)
    end
end

"""
    Milliken(n_segments)

Segmental (Milliken) conductor made of `n_segments` insulated segments, used for large
cross-sections to reduce the skin effect.
"""
struct Milliken <: ConductorShape
    n_segments::Int

    function Milliken(n_segments::Integer)
        n_segments >= 1 ||
            throw(ArgumentError("Milliken: n_segments must be ≥ 1, got $n_segments"))
        return new(n_segments)
    end
end

"""
    Conductor(shape, material; r_out, area_nominal, r_in = 0, R_dc20 = nothing)

Central conductor of a cable core.

# Fields

  - `shape::ConductorShape`: construction, see [`ConductorShape`](@ref).
  - `r_in::T`: inner radius [m]; `0` for a full conductor, `> 0` for a hollow one (oil duct).
  - `r_out::T`: outer radius [m].
  - `area_nominal::T`: nominal cross-section [m²].
  - `material::Material`: conductor material.
  - `R_dc20::Union{T,Nothing}`: DC resistance at 20 °C [Ω/m], overriding the value derived
    from the material; `nothing` to derive it.

The numbers are promoted to a common floating-point type `T`; the material keeps its own.

# Example

```jldoctest
julia> c = Conductor(RoundStranded(37), ALUMINIUM; r_out = 9.1e-3, area_nominal = 240e-6);

julia> c.r_in
0.0
```
"""
struct Conductor{T <: Real}
    shape::ConductorShape
    r_in::T
    r_out::T
    area_nominal::T
    material::Material
    R_dc20::Union{T, Nothing}

    function Conductor(
            shape::ConductorShape, material::Material;
            r_out::Real, area_nominal::Real, r_in::Real = 0, R_dc20::Union{Real, Nothing} = nothing,
        )
        _check_finite("Conductor", (; r_in, r_out, area_nominal))
        r_in >= 0 && r_out - r_in > 0 || throw(
            ArgumentError("Conductor: need 0 ≤ r_in < r_out, got r_in = $r_in, r_out = $r_out"),
        )
        area_nominal > 0 ||
            throw(ArgumentError("Conductor: area_nominal must be positive, got $area_nominal"))
        if R_dc20 !== nothing
            isfinite(R_dc20) && R_dc20 > 0 ||
                throw(ArgumentError("Conductor: R_dc20 must be positive and finite, got $R_dc20"))
        end
        r_in, r_out, area_nominal, R = _floats(r_in, r_out, area_nominal, something(R_dc20, r_out))
        return new{typeof(r_out)}(shape, r_in, r_out, area_nominal, material, R_dc20 === nothing ? nothing : R)
    end
end

inner_radius(c::Conductor) = c.r_in
outer_radius(c::Conductor) = c.r_out
