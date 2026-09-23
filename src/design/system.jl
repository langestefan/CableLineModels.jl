"""
    PlacedCable{T<:Real}

A [`CableDesign`](@ref) at a position in the cross-section of a route.

# Fields

  - `design::CableDesign{T}`
  - `x::T`: horizontal position of the cable centre [m].
  - `y::T`: vertical position of the cable centre [m], negative below ground.
  - `phases::Vector{Symbol}`: phase of each core, in core order, e.g. `[:a]` or
    `[:a, :b, :c, :n]`.
"""
struct PlacedCable{T <: Real}
    design::CableDesign{T}
    x::T
    y::T
    phases::Vector{Symbol}

    function PlacedCable{T}(design::CableDesign, x, y, phases) where {T <: Real}
        _check_finite("PlacedCable", (; x, y))
        phases = _phase_vector(phases)
        n = length(design.cores)
        length(phases) == n || throw(
            ArgumentError(
                "PlacedCable: \"$(design.name)\" has $n core(s), got $(length(phases)) phase(s)",
            ),
        )
        return new{T}(design, x, y, phases)
    end
end

const _Phases = Union{Symbol, AbstractVector{Symbol}, Tuple{Vararg{Symbol}}}

_phase_vector(p::Symbol) = [p]
_phase_vector(p) = collect(Symbol, p)

"""
    PlacedCable(design, x, y, phases)

Place `design` with its centre at (`x`, `y`) [m]. `phases` is one `Symbol` per core, given as
a vector, a tuple, or a single `Symbol` for a single-core cable.
"""
function PlacedCable(design::CableDesign, x::Real, y::Real, phases::_Phases)
    T = float(promote_type(numtype(design), typeof(x), typeof(y)))
    return PlacedCable{T}(design, x, y, phases)
end

PlacedCable{T}(c::PlacedCable) where {T <: Real} = PlacedCable{T}(c.design, c.x, c.y, c.phases)

numtype(::PlacedCable{T}) where {T} = T
_placed_numtype(::AbstractVector{PlacedCable{T}}) where {T} = T
_placed_numtype(v::AbstractVector{<:PlacedCable}) = _eltype_numtype(v)
outer_radius(c::PlacedCable{T}) where {T} = outer_radius(c.design)::T

"""
    Installation

Abstract supertype for how the cables of a [`CableSystem`](@ref) are laid.
"""
abstract type Installation end

"""
    DirectBuried()

Cables buried directly in the soil.
"""
struct DirectBuried <: Installation end

"""
    InDuct(r_duct_in, r_duct_out)

Every cable in its own duct, centred on the cable. Radii in [m].
"""
struct InDuct{T <: Real} <: Installation
    r_duct_in::T
    r_duct_out::T

    function InDuct{T}(r_duct_in, r_duct_out) where {T <: Real}
        _check_annulus("InDuct", r_duct_in, r_duct_out)
        return new{T}(r_duct_in, r_duct_out)
    end
end

InDuct(r_duct_in::Real, r_duct_out::Real) = InDuct{_promote_numtype(r_duct_in, r_duct_out)}(r_duct_in, r_duct_out)

numtype(::InDuct{T}) where {T} = T

_installation_numtype(::DirectBuried) = Union{}
_installation_numtype(i::InDuct) = numtype(i)
_retype(::Type{T}, i::DirectBuried) where {T} = i
_retype(::Type{T}, i::InDuct) where {T} = InDuct{T}(i.r_duct_in, i.r_duct_out)

_placed_radius(::DirectBuried, c::PlacedCable) = outer_radius(c)
_placed_radius(i::InDuct, ::PlacedCable) = i.r_duct_out

_check_installation(::DirectBuried, _) = nothing

function _check_installation(i::InDuct, cables)
    for (k, c) in enumerate(cables)
        _fits_outside(i.r_duct_in, outer_radius(c)) || throw(
            ArgumentError(
                "CableSystem: cable $k (outer radius $(outer_radius(c)) m) does not fit in a " *
                    "duct of inner radius $(i.r_duct_in) m",
            ),
        )
    end
    return nothing
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
    EarthModel{T<:Real}

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

    function EarthModel{T}(rho, eps_r, mu_r, k_th, T_ambient) where {T <: Real}
        _check_finite("EarthModel", (; rho, eps_r, mu_r, k_th, T_ambient))
        rho > 0 || throw(ArgumentError("EarthModel: rho must be positive, got $rho"))
        eps_r >= 1 || throw(ArgumentError("EarthModel: eps_r must be ≥ 1, got $eps_r"))
        mu_r >= 1 || throw(ArgumentError("EarthModel: mu_r must be ≥ 1, got $mu_r"))
        k_th > 0 || throw(ArgumentError("EarthModel: k_th must be positive, got $k_th"))
        return new{T}(rho, eps_r, mu_r, k_th, T_ambient)
    end
end

"""
    EarthModel(; rho, k_th, T_ambient, eps_r = 1, mu_r = 1)

Keyword constructor. Units as in [`EarthModel`](@ref). All numbers are promoted to a common
floating-point type.
"""
function EarthModel(; rho::Real, k_th::Real, T_ambient::Real, eps_r::Real = one(rho), mu_r::Real = one(rho))
    T = _promote_numtype(rho, eps_r, mu_r, k_th, T_ambient)
    return EarthModel{T}(rho, eps_r, mu_r, k_th, T_ambient)
end

EarthModel{T}(e::EarthModel) where {T <: Real} = EarthModel{T}(e.rho, e.eps_r, e.mu_r, e.k_th, e.T_ambient)
Base.convert(::Type{EarthModel{T}}, e::EarthModel) where {T <: Real} = EarthModel{T}(e)
Base.convert(::Type{EarthModel{T}}, e::EarthModel{T}) where {T <: Real} = e

numtype(::EarthModel{T}) where {T} = T

"""
    Compensation{T<:Real}

Abstract supertype for reactive compensation connected along a [`CableSystem`](@ref).
"""
abstract type Compensation{T <: Real} end

numtype(::Compensation{T}) where {T} = T

const _Compensations = Union{AbstractVector{<:Compensation}, Tuple{Vararg{Compensation}}}

_compensation_numtype(v::AbstractVector{<:Compensation}) = _eltype_numtype(v)
_compensation_numtype(t::Tuple{Vararg{Compensation}}) = promote_type(Union{}, map(numtype, t)...)

"""
    CableSystem{T<:Real,I<:Installation,B<:Bonding}

Cables laid along one route, with their installation, bonding and the surrounding earth.

# Fields

  - `cables::Vector{PlacedCable{T}}`
  - `installation::I`: see [`Installation`](@ref).
  - `bonding::B`: see [`Bonding`](@ref).
  - `earth::EarthModel{T}`
  - `length::T`: route length [m].
  - `frequency::T`: nominal frequency [Hz], `0` for DC.
  - `compensation::Vector{Compensation{T}}`: may be empty.

All cables, including their ducts, must lie below ground and must not overlap; overlaps below
1e-6 relative count as touching.

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
struct CableSystem{T <: Real, I <: Installation, B <: Bonding}
    cables::Vector{PlacedCable{T}}
    installation::I
    bonding::B
    earth::EarthModel{T}
    length::T
    frequency::T
    compensation::Vector{Compensation{T}}

    function CableSystem{T, I, B}(
            cables, installation::I, bonding::B, earth, length, frequency, compensation,
        ) where {T <: Real, I <: Installation, B <: Bonding}
        cables = PlacedCable{T}[PlacedCable{T}(c) for c in cables]
        compensation = Compensation{T}[c for c in compensation]
        isempty(cables) && throw(ArgumentError("CableSystem: needs at least one cable"))
        isfinite(length) && length > 0 ||
            throw(ArgumentError("CableSystem: length must be positive and finite, got $length"))
        isfinite(frequency) && frequency >= 0 ||
            throw(ArgumentError("CableSystem: frequency must be ≥ 0 and finite, got $frequency"))
        _check_installation(installation, cables)
        _check_placement(installation, cables)
        return new{T, I, B}(cables, installation, bonding, earth, length, frequency, compensation)
    end
end

function CableSystem{T}(
        cables, installation::Installation, bonding::Bonding, earth, length, frequency, compensation,
    ) where {T <: Real}
    return _cable_system(
        T, cables, _retype(T, installation), bonding, earth, length, frequency, compensation,
    )
end

function _cable_system(
        ::Type{T}, cables, installation::I, bonding::B, earth, length, frequency, compensation,
    ) where {T, I, B}
    return CableSystem{T, I, B}(cables, installation, bonding, earth, length, frequency, compensation)
end

"""
    CableSystem(cables; earth, length, frequency, bonding = BothEnds(),
                installation = DirectBuried(), compensation = ())
    CableSystem(cable::PlacedCable; kwargs...)

Keyword constructor. `cables` is a vector of [`PlacedCable`](@ref), or a single one. Units as
in [`CableSystem`](@ref). All numbers are promoted to a common floating-point type.
"""
function CableSystem(
        cables::AbstractVector{<:PlacedCable};
        earth::EarthModel, length::Real, frequency::Real, bonding::Bonding = BothEnds(),
        installation::Installation = DirectBuried(), compensation::_Compensations = (),
    )
    T = float(
        promote_type(
            _placed_numtype(cables), _installation_numtype(installation), numtype(earth),
            typeof(length), typeof(frequency), _compensation_numtype(compensation),
        ),
    )
    return CableSystem{T}(cables, installation, bonding, earth, length, frequency, compensation)
end

CableSystem(cable::PlacedCable; kwargs...) = CableSystem([cable]; kwargs...)

function CableSystem{T}(s::CableSystem) where {T <: Real}
    return CableSystem{T}(
        s.cables, s.installation, s.bonding, s.earth, s.length, s.frequency, s.compensation,
    )
end

numtype(::CableSystem{T}) where {T} = T

function _check_placement(installation, cables)
    for (i, c) in enumerate(cables)
        r = _placed_radius(installation, c)
        c.y + r < 0 || throw(
            ArgumentError(
                "CableSystem: cable $i reaches above ground (y = $(c.y) m, radius $r m)",
            ),
        )
    end
    for i in eachindex(cables), j in (i + 1):lastindex(cables)
        a, b = cables[i], cables[j]
        d = sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
        _fits_outside(d, _placed_radius(installation, a) + _placed_radius(installation, b)) ||
            throw(ArgumentError("CableSystem: cables $i and $j overlap"))
    end
    return nothing
end
