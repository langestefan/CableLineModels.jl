"""
    Material{T<:Real}

Electrical and thermal properties of a cable material.

# Fields

  - `name::String`: human-readable name.
  - `rho::T`: electrical resistivity at 20 °C [Ω·m].
  - `alpha::T`: temperature coefficient of resistivity at 20 °C [1/K].
  - `eps_r::T`: relative permittivity [-].
  - `mu_r::T`: relative permeability [-] (> 1 for magnetic armour).
  - `tan_delta::T`: dielectric loss factor [-].
  - `k_th::T`: thermal resistivity [K·m/W].

All numeric fields must be finite. They are promoted to a common floating-point type, so any
`Real` subtype can be used, including `ForwardDiff.Dual` and number types carrying
uncertainty.

# Example

```jldoctest
julia> m = Material("copper"; rho = 1.7241e-8, alpha = 3.93e-3);

julia> m.mu_r
1.0
```
"""
struct Material{T <: Real}
    name::String
    rho::T
    alpha::T
    eps_r::T
    mu_r::T
    tan_delta::T
    k_th::T

    function Material(
            name::AbstractString, rho::Real, alpha::Real, eps_r::Real, mu_r::Real,
            tan_delta::Real, k_th::Real,
        )
        _check_finite("material $name", (; rho, alpha, eps_r, mu_r, tan_delta, k_th))
        rho > 0 || throw(ArgumentError("material $name: rho must be positive, got $rho"))
        eps_r >= 1 || throw(ArgumentError("material $name: eps_r must be ≥ 1, got $eps_r"))
        mu_r >= 1 || throw(ArgumentError("material $name: mu_r must be ≥ 1, got $mu_r"))
        tan_delta >= 0 ||
            throw(ArgumentError("material $name: tan_delta must be ≥ 0, got $tan_delta"))
        k_th >= 0 || throw(ArgumentError("material $name: k_th must be ≥ 0, got $k_th"))
        values = _floats(rho, alpha, eps_r, mu_r, tan_delta, k_th)
        return new{eltype(values)}(String(name), values...)
    end
end

"""
    Material(name; rho, alpha = 0, eps_r = 1, mu_r = 1, tan_delta = 0, k_th = 0)

Keyword constructor. Units as in [`Material`](@ref).
"""
function Material(
        name::AbstractString;
        rho::Real, alpha::Real = 0, eps_r::Real = 1, mu_r::Real = 1, tan_delta::Real = 0,
        k_th::Real = 0,
    )
    return Material(name, rho, alpha, eps_r, mu_r, tan_delta, k_th)
end

"""
    COPPER

Annealed copper conductor material.
"""
const COPPER = Material("copper"; rho = 1.7241e-8, alpha = 3.93e-3)

"""
    ALUMINIUM

Aluminium conductor material.
"""
const ALUMINIUM = Material("aluminium"; rho = 2.8264e-8, alpha = 4.03e-3)

"""
    LEAD

Lead (alloy) sheath material.
"""
const LEAD = Material("lead"; rho = 21.4e-8, alpha = 4.0e-3)

"""
    ALUMINIUM_SHEATH

Aluminium sheath material. Its resistivity differs slightly from that of aluminium
conductors ([`ALUMINIUM`](@ref)).
"""
const ALUMINIUM_SHEATH = Material("aluminium sheath"; rho = 2.84e-8, alpha = 4.03e-3)

"""
    STEEL

Steel armour material, with a typical relative permeability for armour wires. `mu_r`
depends strongly on the steel grade.
"""
const STEEL = Material("steel"; rho = 13.8e-8, alpha = 4.5e-3, mu_r = 300.0)

"""
    XLPE

Cross-linked polyethylene insulation. `tan_delta` is the value for high-voltage cables
(U₀ > 18 kV); medium-voltage cables have a higher loss factor, so build a variant with
`Material` for those.
"""
const XLPE = Material("XLPE"; rho = 1.0e17, eps_r = 2.5, tan_delta = 1.0e-3, k_th = 3.5)

"""
    PVC

Polyvinyl chloride insulation or jacket. `k_th` is the value for cables rated up to 3 kV.
"""
const PVC = Material("PVC"; rho = 1.0e13, eps_r = 8.0, tan_delta = 0.1, k_th = 5.0)

"""
    EPR

Ethylene propylene rubber insulation. `tan_delta` is the value for U₀ ≤ 18 kV and `k_th` the
value for cables rated up to 3 kV; build a variant with `Material` for other ratings.
"""
const EPR = Material("EPR"; rho = 1.0e15, eps_r = 3.0, tan_delta = 0.02, k_th = 3.5)

"""
    PAPER_OIL

Oil-impregnated paper insulation (oil-filled cables). `tan_delta` is the value for
U₀ ≤ 36 kV; it decreases slightly at higher voltages.
"""
const PAPER_OIL = Material(
    "oil-impregnated paper"; rho = 1.0e15, eps_r = 3.5, tan_delta = 3.5e-3, k_th = 5.0,
)

"""
    MASS_IMPREGNATED

Mass-impregnated paper insulation (MI HVDC and GPLK).
"""
const MASS_IMPREGNATED = Material(
    "mass-impregnated paper"; rho = 1.0e15, eps_r = 4.0, tan_delta = 0.01, k_th = 6.0,
)

"""
    SEMICON

Semiconducting screen compound. Only used for geometry: semicon layers are treated as part of
the adjacent conductor when computing capacitance.
"""
const SEMICON = Material("semicon"; rho = 1.0, eps_r = 1000.0, k_th = 2.5)
