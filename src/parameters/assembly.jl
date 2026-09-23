# Every metallic part of every cable (core conductor, screen, sheath, armour) is one
# conductor, i.e. one row and column of Z and Y, in the order of `_system_metals`.

# One metallic conductor: the object it comes from and its label, e.g. `:c2_screen`.
struct _Metal
    element::Union{Conductor, Layer}
    label::Symbol
end

_kind(::Conductor) = :core
_kind(::Union{TubularScreen, WireScreen}) = :screen
_kind(::Armour) = :armour

# Metallic conductors of cable `i`, inside-out: per core its conductor and then its metallic
# layers, then the metallic common layers. A kind that occurs once gets a plain label
# (`:c1_core`); a kind that occurs several times is numbered in order (`:c1_core1`, …).
function _cable_metals(i, design::CableDesign)
    elements = Union{Conductor, Layer}[]
    for core in design.cores
        push!(elements, core.conductor)
        append!(elements, metallic_layers(core))
    end
    append!(elements, filter(_is_metallic, design.common_layers))
    kinds = map(_kind, elements)
    seen = Dict{Symbol, Int}()
    return map(elements, kinds) do element, kind
        seen[kind] = get(seen, kind, 0) + 1
        suffix = count(==(kind), kinds) == 1 ? "" : string(seen[kind])
        _Metal(element, Symbol("c$(i)_$kind$suffix"))
    end
end

# All conductors of the system: cable 1 first, then cable 2, and so on.
function _system_metals(sys::CableSystem)
    return reduce(vcat, [_cable_metals(i, c.design) for (i, c) in enumerate(sys.cables)])
end

# At DC there is no inductive or capacitive coupling, so Z is diagonal with the DC
# resistances and Y is zero.
function _zy_dc(metals, T_conductor, T_screen)
    R = [_R_dc(m.element, T_conductor, T_screen) for m in metals]
    T = float(mapreduce(typeof, promote_type, R))
    n = length(metals)
    Z = zeros(Complex{T}, n, n)
    for i in 1:n
        Z[i, i] = R[i]
    end
    return Z, zeros(Complex{T}, n, n)
end
