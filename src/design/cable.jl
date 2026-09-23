"""
    CableCore(conductor, layers = Layer[])

One conductor and the concentric layers around it, listed inside-out, e.g. conductor screen,
insulation, insulation screen, metallic screen.

# Fields

  - `conductor::Conductor`
  - `layers::Vector{Layer}`: inside-out; may be empty.

Layers must not overlap each other or the conductor; gaps are allowed, and overlaps below
1e-6 relative count as touching.

# Example

```jldoctest
julia> c = Conductor(RoundSolid(), COPPER; r_out = 5.0e-3, area_nominal = 78e-6);

julia> core = CableCore(c, [InsulationLayer(5.0e-3, 8.0e-3, XLPE)]);

julia> outer_radius(core)
0.008
```
"""
struct CableCore
    conductor::Conductor
    layers::Vector{Layer}

    function CableCore(conductor::Conductor, layers::AbstractVector{<:Layer} = Layer[])
        _check_stack("CableCore", outer_radius(conductor), layers)
        return new(conductor, layers)
    end
end

function outer_radius(c::CableCore)
    isempty(c.layers) && return outer_radius(c.conductor)
    return outer_radius(last(c.layers))
end

"""
    metallic_layers(core::CableCore)

Metallic layers of `core` (screens, sheaths and armour), inside-out.
"""
metallic_layers(c::CableCore) = filter(_is_metallic, c.layers)

"""
    CoreLayout

Abstract supertype for the arrangement of the cores inside a [`CableDesign`](@ref).
"""
abstract type CoreLayout end

"""
    SingleCore()

One core on the cable axis.
"""
struct SingleCore <: CoreLayout end

"""
    FourCoreLV(r_center; lay_length = nothing)

Four cores at 90° spacing, each with its centre at distance `r_center` [m] from the cable
axis. Used for low-voltage cables with three phases and a neutral. `lay_length` [m] is the
axial length over which the cores make one full helical turn; `nothing` for straight cores.
Laid-up cores are longer than the cable, which increases their resistance per metre of
cable by the factor of IEC 60287-1-1, Annex A.
"""
struct FourCoreLV{T <: Real} <: CoreLayout
    r_center::T
    lay_length::Union{T, Nothing}

    function FourCoreLV(r_center::Real; lay_length::Union{Real, Nothing} = nothing)
        isfinite(r_center) && r_center > 0 || throw(
            ArgumentError("FourCoreLV: r_center must be positive and finite, got $r_center"),
        )
        if lay_length !== nothing
            isfinite(lay_length) && lay_length > 0 || throw(
                ArgumentError("FourCoreLV: lay_length must be positive and finite, got $lay_length"),
            )
        end
        r_center, L = _floats(r_center, something(lay_length, r_center))
        return new{typeof(r_center)}(r_center, lay_length === nothing ? nothing : L)
    end
end

_n_cores(::SingleCore) = 1
_n_cores(::FourCoreLV) = 4

_lay_up_factor(::SingleCore, _) = 1

function _lay_up_factor(l::FourCoreLV, core::CableCore)
    l.lay_length === nothing && return 1
    C_fL = 1.53
    return sqrt(1 + (pi * C_fL * 2 * outer_radius(core) / l.lay_length)^2)
end

_cores_radius(::SingleCore, cores) = outer_radius(only(cores))
_cores_radius(l::FourCoreLV, cores) = l.r_center + maximum(outer_radius, cores)

_check_layout(::SingleCore, _) = nothing

function _check_layout(l::FourCoreLV, cores)
    for i in 1:4, j in (i + 1):4
        d = 2 * l.r_center * sinpi((j - i) / 4)
        _fits_outside(d, outer_radius(cores[i]) + outer_radius(cores[j])) || throw(
            ArgumentError("CableDesign: cores $i and $j overlap at r_center = $(l.r_center) m"),
        )
    end
    return nothing
end

"""
    CableDesign(name, cores, layout = SingleCore(); U0, common_layers = Layer[], system_type = :ac)
    CableDesign(name, core::CableCore, layout = SingleCore(); kwargs...)

Complete physical description of a cable. `cores` is a vector of [`CableCore`](@ref), or a
single core.

# Fields

  - `name::String`
  - `cores::Vector{CableCore}`: one per conductor, in the order of `layout`.
  - `layout::CoreLayout`: arrangement of the cores, see [`CoreLayout`](@ref).
  - `common_layers::Vector{Layer}`: layers around all cores, inside-out, e.g. belt,
    common sheath, armour, serving. Usually empty for single-core cables, where all layers
    belong to the core.
  - `U0::Real`: rated phase-to-earth voltage [V].
  - `system_type::Symbol`: `:ac` or `:dc`.

# Example

```jldoctest
julia> c = Conductor(RoundSolid(), COPPER; r_out = 5.0e-3, area_nominal = 78e-6);

julia> core = CableCore(c, [InsulationLayer(5.0e-3, 8.0e-3, XLPE)]);

julia> d = CableDesign("demo", core; U0 = 6.35e3, common_layers = [Jacket(8.0e-3, 10.0e-3, PVC)]);

julia> outer_radius(d)
0.01
```
"""
struct CableDesign
    name::String
    cores::Vector{CableCore}
    layout::CoreLayout
    common_layers::Vector{Layer}
    U0::Real
    system_type::Symbol

    function CableDesign(
            name::AbstractString, cores::AbstractVector{CableCore}, layout::CoreLayout = SingleCore();
            U0::Real, common_layers::AbstractVector{<:Layer} = Layer[], system_type::Symbol = :ac,
        )
        system_type in (:ac, :dc) ||
            throw(ArgumentError("CableDesign: system_type must be :ac or :dc, got :$system_type"))
        isfinite(U0) && U0 > 0 ||
            throw(ArgumentError("CableDesign: U0 must be positive and finite, got $U0"))
        n = _n_cores(layout)
        length(cores) == n || throw(
            ArgumentError(
                "CableDesign: $(nameof(typeof(layout))) needs $n core(s), got $(length(cores))",
            ),
        )
        _check_layout(layout, cores)
        _check_stack("CableDesign", _cores_radius(layout, cores), common_layers)
        return new(name, cores, layout, common_layers, float(U0), system_type)
    end
end

function CableDesign(name::AbstractString, core::CableCore, layout::CoreLayout = SingleCore(); kwargs...)
    return CableDesign(name, [core], layout; kwargs...)
end

"""
    CableDesign(material, area; U0, t_insulation = typical for U0, screen_area = 16e-6)

Typical single-core XLPE cable with a round stranded conductor of `material` (e.g.
[`COPPER`](@ref) or [`ALUMINIUM`](@ref)) and nominal cross-section `area` [m²], rated at
phase-to-earth voltage `U0` [V]. The cable has, inside-out:

  - the compacted conductor;
  - a 0.5 mm semiconducting conductor screen;
  - XLPE insulation of thickness `t_insulation` [m], by default a typical thickness for the
    medium-voltage class that covers `U0` (up to 18 kV);
  - a 0.5 mm semiconducting insulation screen;
  - a copper wire screen of cross-section `screen_area` [m²];
  - a PVC jacket.

For a specific cable, build it layer by layer from a [`Conductor`](@ref) and
[`CableCore`](@ref) instead.

# Example

```jldoctest
julia> d = CableDesign(ALUMINIUM, 240e-6; U0 = 12e3);

julia> d.name
"1x240 mm² aluminium, U0 = 12.0 kV"
```
"""
function CableDesign(
        material::Material, area::Real;
        U0::Real, t_insulation::Real = _insulation_thickness(U0), screen_area::Real = 16.0e-6,
    )
    isfinite(area) && area > 0 ||
        throw(ArgumentError("CableDesign: area must be positive and finite, got $area"))
    n_strands = area <= 35.0e-6 ? 7 : area <= 150.0e-6 ? 19 : area <= 300.0e-6 ? 37 : 61
    r_c = sqrt(area / (pi * 0.92))
    conductor = Conductor(RoundStranded(n_strands), material; r_out = r_c, area_nominal = area)

    r1 = r_c + 0.5e-3
    r2 = r1 + t_insulation
    r3 = r2 + 0.5e-3
    r_wire = 0.4e-3
    n_wires = ceil(Int, screen_area / (pi * r_wire^2))
    r4 = r3 + 2 * r_wire
    t_jacket = max(0.035 * 2 * r4 + 1.0e-3, 1.4e-3)
    core = CableCore(
        conductor, [
            SemiconLayer(r_c, r1),
            InsulationLayer(r1, r2, XLPE),
            SemiconLayer(r2, r3),
            WireScreen(r3 + r_wire, n_wires, r_wire, 20 * (r3 + r_wire), COPPER),
            Jacket(r4, r4 + t_jacket, PVC),
        ],
    )
    name = "1x$(round(Int, area * 1.0e6)) mm² $(material.name), U0 = $(U0 / 1.0e3) kV"
    return CableDesign(name, core; U0)
end

function _insulation_thickness(U0)
    for (U, t) in ((3.6e3, 2.5e-3), (6.0e3, 3.4e-3), (8.7e3, 4.5e-3), (12.0e3, 5.5e-3), (18.0e3, 8.0e-3))
        U0 <= U && return t
    end
    throw(ArgumentError("CableDesign: no typical insulation thickness above U0 = 18 kV, pass t_insulation"))
end

function outer_radius(d::CableDesign)
    isempty(d.common_layers) && return _cores_radius(d.layout, d.cores)
    return outer_radius(last(d.common_layers))
end
