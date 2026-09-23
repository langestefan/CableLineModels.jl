"""
    PlacedCable(design, x, y, phases)

A [`CableDesign`](@ref) at a position in the cross-section of a route. `phases` is one
`Symbol` per core, given as a vector, or a single `Symbol` for a single-core cable.

# Fields

  - `design::CableDesign`
  - `x::T`: horizontal position of the cable centre [m].
  - `y::T`: vertical position of the cable centre [m], negative below ground.
  - `phases::Vector{Symbol}`: phase of each core, in core order, e.g. `[:a]` or
    `[:a, :b, :c, :n]`.
"""
struct PlacedCable{T <: Real}
    design::CableDesign
    x::T
    y::T
    phases::Vector{Symbol}

    function PlacedCable(
            design::CableDesign, x::Real, y::Real, phases::Union{Symbol, AbstractVector{Symbol}},
        )
        _check_finite("PlacedCable", (; x, y))
        phases = phases isa Symbol ? [phases] : phases
        n = length(design.cores)
        length(phases) == n || throw(
            ArgumentError(
                "PlacedCable: \"$(design.name)\" has $n core(s), got $(length(phases)) phase(s)",
            ),
        )
        x, y = _floats(x, y)
        return new{typeof(x)}(design, x, y, phases)
    end
end

outer_radius(c::PlacedCable) = outer_radius(c.design)

"""
    trefoil(design; depth = 1.0)

Three single-core cables of `design` touching in trefoil, phases `:a`, `:b` and `:c`, with
the two lower cables at `depth` [m] below ground and the third on top.
"""
function trefoil(design::CableDesign; depth::Real = 1.0)
    r = outer_radius(design)
    return [
        PlacedCable(design, -r, -depth, :a),
        PlacedCable(design, r, -depth, :b),
        PlacedCable(design, zero(r), -depth + sqrt(3) * r, :c),
    ]
end

"""
    Bonding

Abstract supertype for how the metallic screens of a [`CableSystem`](@ref) are earthed.
"""
abstract type Bonding end

"""
    BothEnds()

Screens bonded and earthed at both ends of the route.
"""
struct BothEnds <: Bonding end

"""
    SinglePoint()

Screens earthed at one end only, so no screen current flows at the fundamental frequency.
"""
struct SinglePoint <: Bonding end

"""
    CrossBonded(n_major)

Screens cross-bonded in `n_major` major sections, each of three minor sections.
"""
struct CrossBonded <: Bonding
    n_major::Int

    function CrossBonded(n_major::Integer)
        n_major >= 1 || throw(ArgumentError("CrossBonded: n_major must be ≥ 1, got $n_major"))
        return new(n_major)
    end
end

"""
    EarthModel(; rho = 100, k_th = 1, T_ambient = 15, eps_r = 1, mu_r = 1)

Electrical and thermal properties of the soil around a [`CableSystem`](@ref).

# Fields

  - `rho::T`: electrical resistivity [Ω·m].
  - `eps_r::T`: relative permittivity [-].
  - `mu_r::T`: relative permeability [-].
  - `k_th::T`: thermal resistivity [K·m/W].
  - `T_ambient::T`: ambient temperature at cable depth [°C].
"""
struct EarthModel{T <: Real}
    rho::T
    eps_r::T
    mu_r::T
    k_th::T
    T_ambient::T

    function EarthModel(;
            rho::Real = 100, k_th::Real = 1, T_ambient::Real = 15, eps_r::Real = 1, mu_r::Real = 1,
        )
        _check_finite("EarthModel", (; rho, eps_r, mu_r, k_th, T_ambient))
        rho > 0 || throw(ArgumentError("EarthModel: rho must be positive, got $rho"))
        eps_r >= 1 || throw(ArgumentError("EarthModel: eps_r must be ≥ 1, got $eps_r"))
        mu_r >= 1 || throw(ArgumentError("EarthModel: mu_r must be ≥ 1, got $mu_r"))
        k_th > 0 || throw(ArgumentError("EarthModel: k_th must be positive, got $k_th"))
        values = _floats(rho, eps_r, mu_r, k_th, T_ambient)
        return new{eltype(values)}(values...)
    end
end

"""
    CableSystem(cables; earth = EarthModel(), length = 1e3, frequency = 50, bonding = BothEnds())

Cables laid along one route, with their bonding and the surrounding earth. `cables` is a
vector of [`PlacedCable`](@ref), or a single one.

# Fields

  - `cables::Vector{PlacedCable}`
  - `bonding::Bonding`: see [`Bonding`](@ref).
  - `earth::EarthModel`
  - `length::T`: route length [m].
  - `frequency::T`: nominal frequency [Hz], `0` for DC.

All cables must lie below ground and must not overlap; overlaps below 1e-6 relative count
as touching.

# Example

```jldoctest
julia> c = Conductor(RoundSolid(), COPPER; r_out = 5.0e-3, area_nominal = 78e-6);

julia> d = CableDesign("demo", CableCore(c, [InsulationLayer(5.0e-3, 8.0e-3, XLPE)]); U0 = 6.35e3);

julia> cables = [PlacedCable(d, x, -1.0, p) for (x, p) in ((-0.1, :a), (0.0, :b), (0.1, :c))];

julia> earth = EarthModel(; rho = 100.0, k_th = 1.0, T_ambient = 15.0);

julia> sys = CableSystem(cables; earth, length = 5.0e3, frequency = 50.0);

julia> sys.bonding
BothEnds()
```
"""
struct CableSystem{T <: Real}
    cables::Vector{PlacedCable}
    bonding::Bonding
    earth::EarthModel
    length::T
    frequency::T

    function CableSystem(
            cables::AbstractVector{<:PlacedCable};
            earth::EarthModel = EarthModel(), length::Real = 1.0e3, frequency::Real = 50,
            bonding::Bonding = BothEnds(),
        )
        isempty(cables) && throw(ArgumentError("CableSystem: needs at least one cable"))
        isfinite(length) && length > 0 ||
            throw(ArgumentError("CableSystem: length must be positive and finite, got $length"))
        isfinite(frequency) && frequency >= 0 ||
            throw(ArgumentError("CableSystem: frequency must be ≥ 0 and finite, got $frequency"))
        _check_placement(cables)
        length, frequency = _floats(length, frequency)
        return new{typeof(length)}(cables, bonding, earth, length, frequency)
    end
end

CableSystem(cable::PlacedCable; kwargs...) = CableSystem([cable]; kwargs...)

function _check_placement(cables)
    for (i, c) in enumerate(cables)
        c.y + outer_radius(c) < 0 || throw(
            ArgumentError(
                "CableSystem: cable $i reaches above ground (y = $(c.y) m, radius $(outer_radius(c)) m)",
            ),
        )
    end
    for i in eachindex(cables), j in (i + 1):lastindex(cables)
        a, b = cables[i], cables[j]
        d = sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
        _fits_outside(d, outer_radius(a) + outer_radius(b)) ||
            throw(ArgumentError("CableSystem: cables $i and $j overlap"))
    end
    return nothing
end
