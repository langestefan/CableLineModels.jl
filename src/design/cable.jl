"""
    CableCore{T<:Real}

One conductor and the concentric layers around it, listed inside-out, e.g. conductor screen,
insulation, insulation screen, metallic screen.

# Fields

  - `conductor::Conductor{T}`
  - `layers::Vector{Layer{T}}`: inside-out; may be empty.

Layers must not overlap each other or the conductor; gaps are allowed, and overlaps below
1e-6 relative count as touching. All numbers are promoted to a common floating-point type.

# Example

```jldoctest
julia> c = Conductor(RoundSolid(), COPPER; r_out = 5.0e-3, area_nominal = 78e-6);

julia> core = CableCore(c, [InsulationLayer(5.0e-3, 8.0e-3, XLPE)]);

julia> outer_radius(core)
0.008
```
"""
struct CableCore{T <: Real}
    conductor::Conductor{T}
    layers::Vector{Layer{T}}

    function CableCore{T}(conductor::Conductor, layers) where {T <: Real}
        conductor = Conductor{T}(conductor)
        layers = _layer_vector(T, layers)
        _check_stack("CableCore", outer_radius(conductor), layers)
        return new{T}(conductor, layers)
    end
end

"""
    CableCore(conductor, layers = ())

Construct a core from a [`Conductor`](@ref) and its layers, listed inside-out as a vector
or tuple.
"""
function CableCore(conductor::Conductor, layers::_Layers = ())
    T = float(promote_type(numtype(conductor), _layers_numtype(layers)))
    return CableCore{T}(conductor, layers)
end

CableCore{T}(c::CableCore) where {T <: Real} = CableCore{T}(c.conductor, c.layers)

numtype(::CableCore{T}) where {T} = T
function outer_radius(c::CableCore{T}) where {T}
    isempty(c.layers) && return outer_radius(c.conductor)
    return outer_radius(last(c.layers))::T
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
    FourCoreLV(r_center)

Four cores at 90° spacing, each with its centre at distance `r_center` [m] from the cable
axis. Used for low-voltage cables with three phases and a neutral.
"""
struct FourCoreLV{T <: Real} <: CoreLayout
    r_center::T

    function FourCoreLV{T}(r_center) where {T <: Real}
        isfinite(r_center) && r_center > 0 || throw(
            ArgumentError("FourCoreLV: r_center must be positive and finite, got $r_center"),
        )
        return new{T}(r_center)
    end
end

FourCoreLV(r_center::Real) = FourCoreLV{float(typeof(r_center))}(r_center)

numtype(::FourCoreLV{T}) where {T} = T

_n_cores(::SingleCore) = 1
_n_cores(::FourCoreLV) = 4
_layout_numtype(::SingleCore) = Union{}
_layout_numtype(l::FourCoreLV) = numtype(l)
_retype(::Type{T}, l::SingleCore) where {T} = l
_retype(::Type{T}, l::FourCoreLV) where {T} = FourCoreLV{T}(l.r_center)

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
    CableDesign{T<:Real,L<:CoreLayout}

Complete physical description of a cable.

# Fields

  - `name::String`
  - `cores::Vector{CableCore{T}}`: one per conductor, in the order of `layout`.
  - `layout::L`: arrangement of the cores, see [`CoreLayout`](@ref).
  - `common_layers::Vector{Layer{T}}`: layers around all cores, inside-out, e.g. belt,
    common sheath, armour, serving. Usually empty for single-core cables, where all layers
    belong to the core.
  - `U0::T`: rated phase-to-earth voltage [V].
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
struct CableDesign{T <: Real, L <: CoreLayout}
    name::String
    cores::Vector{CableCore{T}}
    layout::L
    common_layers::Vector{Layer{T}}
    U0::T
    system_type::Symbol

    function CableDesign{T, L}(
            name, cores, layout::L, common_layers, U0, system_type::Symbol,
        ) where {T <: Real, L <: CoreLayout}
        cores = CableCore{T}[CableCore{T}(c) for c in cores]
        common_layers = _layer_vector(T, common_layers)
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
        return new{T, L}(name, cores, layout, common_layers, U0, system_type)
    end
end

function CableDesign{T}(name, cores, layout::CoreLayout, common_layers, U0, system_type) where {T <: Real}
    return _cable_design(T, name, cores, _retype(T, layout), common_layers, U0, system_type)
end

function _cable_design(::Type{T}, name, cores, layout::L, common_layers, U0, system_type) where {T, L}
    return CableDesign{T, L}(name, cores, layout, common_layers, U0, system_type)
end

"""
    CableDesign(name, cores, layout = SingleCore(); U0, common_layers = (), system_type = :ac)
    CableDesign(name, core::CableCore, layout = SingleCore(); kwargs...)

Keyword constructor. `cores` is a vector of [`CableCore`](@ref), or a single core. Units as
in [`CableDesign`](@ref); `common_layers` is a vector or tuple. All numbers are promoted to a common floating-point type.
"""
function CableDesign(
        name::AbstractString, cores::AbstractVector{<:CableCore},
        layout::CoreLayout = SingleCore();
        U0, common_layers::_Layers = (), system_type::Symbol = :ac,
    )
    T = float(
        promote_type(
            _cores_numtype(cores), _layout_numtype(layout), _layers_numtype(common_layers),
            typeof(U0),
        ),
    )
    return CableDesign{T}(String(name), cores, layout, common_layers, U0, system_type)
end

function CableDesign(name::AbstractString, core::CableCore, layout::CoreLayout = SingleCore(); kwargs...)
    return CableDesign(name, [core], layout; kwargs...)
end

function CableDesign{T}(d::CableDesign) where {T <: Real}
    return CableDesign{T}(d.name, d.cores, d.layout, d.common_layers, d.U0, d.system_type)
end

Base.convert(::Type{CableDesign{T}}, d::CableDesign) where {T <: Real} = CableDesign{T}(d)
Base.convert(::Type{CableDesign{T}}, d::CableDesign{T}) where {T <: Real} = d

_cores_numtype(::AbstractVector{CableCore{T}}) where {T} = T
_cores_numtype(v::AbstractVector{<:CableCore}) = _eltype_numtype(v)

numtype(::CableDesign{T}) where {T} = T

function outer_radius(d::CableDesign{T}) where {T}
    isempty(d.common_layers) && return _cores_radius(d.layout, d.cores)::T
    return outer_radius(last(d.common_layers))::T
end
