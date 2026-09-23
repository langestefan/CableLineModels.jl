"""
    ParameterMethod

Abstract supertype of the methods that compute per-unit-length series impedance and shunt
admittance matrices, see [`compute_ZY`](@ref).
"""
abstract type ParameterMethod end

"""
    IEC60287Method()

Parameters following IEC 60287-1-1, for the fundamental frequency and DC.
"""
struct IEC60287Method <: ParameterMethod end

"""
    LoopMethod(earth = :wedepohl)

Loop-impedance method with tubular conductor impedances, valid at any frequency. `earth`
selects the earth-return impedance: `:wedepohl` (closed form) or `:pollaczek` (numerical
integral).
"""
struct LoopMethod <: ParameterMethod
    earth::Symbol

    function LoopMethod(earth::Symbol = :wedepohl)
        earth in (:wedepohl, :pollaczek) || throw(
            ArgumentError("LoopMethod: earth must be :wedepohl or :pollaczek, got :$earth"),
        )
        return new(earth)
    end
end

"""
    ZYData{T<:Real}

Per-unit-length impedance and admittance matrices of every metallic conductor of a
[`CableSystem`](@ref), at one or more frequencies.

# Fields

  - `freqs::Vector{T}`: frequencies [Hz].
  - `Z::Array{Complex{T},3}`: series impedance [Ω/m], `n × n × length(freqs)`.
  - `Y::Array{Complex{T},3}`: shunt admittance [S/m], `n × n × length(freqs)`.
  - `labels::Vector{Symbol}`: name of each of the `n` conductors, see [`compute_ZY`](@ref).
  - `T_conductor::T`: temperature used for the resistivities [°C].
"""
struct ZYData{T <: Real}
    freqs::Vector{T}
    Z::Array{Complex{T}, 3}
    Y::Array{Complex{T}, 3}
    labels::Vector{Symbol}
    T_conductor::T

    function ZYData{T}(freqs, Z, Y, labels, T_conductor) where {T <: Real}
        dims = (length(labels), length(labels), length(freqs))
        size(Z) == dims && size(Y) == dims || throw(
            ArgumentError(
                "ZYData: Z and Y must be $(join(dims, "×")), got $(join(size(Z), "×")) and " *
                    "$(join(size(Y), "×"))",
            ),
        )
        allunique(labels) || throw(ArgumentError("ZYData: labels must be unique"))
        return new{T}(freqs, Z, Y, labels, T_conductor)
    end
end

function ZYData(freqs::AbstractVector{<:Real}, Z::AbstractArray, Y::AbstractArray, labels, T_conductor::Real)
    T = float(promote_type(eltype(freqs), real(eltype(Z)), real(eltype(Y)), typeof(T_conductor)))
    return ZYData{T}(freqs, Z, Y, labels, T_conductor)
end

numtype(::ZYData{T}) where {T} = T

"""
    compute_ZY(sys::CableSystem, method::ParameterMethod, freqs; T_conductor = 90) -> ZYData

Series impedance and shunt admittance matrices of every metallic conductor of `sys`, per
unit length, at the frequencies `freqs` [Hz] (a number or a vector). Resistivities of all
metallic layers are taken at `T_conductor` [°C]. The result has the number type of `sys`,
`freqs` and `T_conductor` combined.

Every metallic layer is a separate conductor, ordered by cable, then by core from the
conductor outwards, then the common layers of the cable. Labels are `:c<i>_core`,
`:c<i>_screen` and `:c<i>_armour` for cable `i`; a kind that occurs more than once in a
cable is numbered inside-out, e.g. `:c1_core1` to `:c1_core4` for a four-core cable.
Bonding is not applied; see section 6 of the specification.

# DC

At `f = 0`, `Z` is diagonal with the DC resistances

``R_{dc}(T) = R_{dc,20}\\,[1 + \\alpha (T - 20)]``

where ``R_{dc,20}`` is the conductor's `R_dc20`, or else `rho / area_nominal`; for a
tubular screen `rho` over its annulus area, and for a wire layer `rho` over the total wire
area. `Y` is zero: the leakage conductance of the insulation is negligible for network
models (about 1e-16 S/m for XLPE) and too uncertain to be worth modelling, because the DC
conductivity of insulation depends strongly on temperature and electric field.

# Example

```jldoctest
julia> c = Conductor(RoundSolid(), COPPER; r_out = 5.0e-3, area_nominal = 78.5e-6);

julia> core = CableCore(c, [InsulationLayer(5.0e-3, 8.0e-3, XLPE), TubularScreen(8.0e-3, 8.5e-3, LEAD), Jacket(8.5e-3, 10.0e-3, PVC)]);

julia> sys = CableSystem(PlacedCable(CableDesign("demo", core; U0 = 6.35e3), 0.0, -1.0, :a); earth = EarthModel(; rho = 100.0, k_th = 1.0, T_ambient = 15.0), length = 1.0e3, frequency = 0.0);

julia> zy = compute_ZY(sys, LoopMethod(), 0.0; T_conductor = 20.0);

julia> zy.labels
2-element Vector{Symbol}:
 :c1_core
 :c1_screen

julia> real(zy.Z[1, 1, 1]) ≈ COPPER.rho / 78.5e-6
true
```
"""
function compute_ZY(sys::CableSystem, method::ParameterMethod, freqs; T_conductor::Real = 90)
    T = float(promote_type(numtype(sys), _freqs_numtype(freqs), typeof(T_conductor)))
    return _compute_ZY(sys, method, _freq_vector(T, freqs), convert(T, T_conductor))
end

_freqs_numtype(f::Real) = typeof(f)
_freqs_numtype(f::AbstractVector{<:Real}) = eltype(f)
_freq_vector(::Type{T}, f::Real) where {T} = T[f]
_freq_vector(::Type{T}, f::AbstractVector{<:Real}) where {T} = collect(T, f)

function _compute_ZY(sys::CableSystem, method::ParameterMethod, freqs::Vector{T}, T_conductor::T) where {T}
    isempty(freqs) && throw(ArgumentError("compute_ZY: freqs must not be empty"))
    for f in freqs
        isfinite(f) && f >= 0 ||
            throw(ArgumentError("compute_ZY: frequencies must be finite and ≥ 0, got $f"))
    end
    _check_finite("compute_ZY", (; T_conductor))
    metals = _system_metals(sys)
    n = length(metals)
    Z = zeros(Complex{T}, n, n, length(freqs))
    Y = zeros(Complex{T}, n, n, length(freqs))
    for (k, f) in enumerate(freqs)
        Zk, Yk = iszero(f) ? _zy_dc(metals, T_conductor) : _zy_ac(sys, method, f, T_conductor)
        Z[:, :, k] = Zk
        Y[:, :, k] = Yk
    end
    return ZYData{T}(freqs, Z, Y, [m.label for m in metals], T_conductor)
end

function _zy_ac(::CableSystem, ::IEC60287Method, _, _)
    throw(UnsupportedError("IEC60287Method is pending IEC 60287-1-1", "use LoopMethod()"))
end

function _zy_ac(::CableSystem, method::ParameterMethod, _, _)
    throw(UnsupportedError("compute_ZY: $(nameof(typeof(method))) at f > 0 is not implemented yet"))
end
