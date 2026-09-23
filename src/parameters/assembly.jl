# Assembly of the conductor matrices of a whole `CableSystem`.
#
# Every metallic part of every cable (core conductor, screen, sheath, armour) becomes one
# conductor, i.e. one row and column of Z and Y. This file
#   1. lists those conductors in a fixed order and gives each a label (`_system_metals`), and
#   2. fills the DC matrices (`_zy_dc`).
#
# Conductor numbering: index 1…n in the order of `_system_metals`, and index 0 stands for
# earth (remote ground), which has no row of its own in G.
#
# In the diagrams below, `─[R]─` is a leakage resistor formed by the non-metallic layers
# between two metallic parts, and `⏚` is earth.

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

# DC matrices.
#
# Z: at DC there is no inductive coupling, so Z is diagonal with each conductor's DC
# resistance.
#
# Y: the leakage conductance matrix G, built as a nodal admittance matrix. Every stretch of
# non-metallic layers between two metallic conductors (or between the outermost one and
# earth) is a resistor. Its resistance per metre is the sum of ρ·ln(r_out/r_in)/2π over the
# layers in it (coaxial layers in series). Cables do not leak into each other, only into
# earth, so G is block diagonal with one block per cable.
#
# Single-core MV cable:
#
#     conductor | semicon | XLPE | semicon | wire screen | PVC jacket | soil
#     ─────────   ──────────────────────────   ───────────   ──────────
#      metal #1       R₁ = Σ ρ·ln(ro/ri)/2π     metal #2        R₂
#
#     c1_core ──[ R₁ ]── c1_screen ──[ R₂ ]── ⏚
#
#     G block, gₖ = 1/Rₖ:        core    screen
#                       core   [  g₁      -g₁     ]
#                       screen [ -g₁    g₁ + g₂   ]
#
# Three such cables give three independent 2×2 blocks:
#
#               c1_core c1_scr c2_core c2_scr c3_core c3_scr
#     c1_core  [   ■      ■                                ]
#     c1_scr   [   ■      ■                                ]
#     c2_core  [                 ■      ■                  ]
#     c2_scr   [                 ■      ■                  ]
#     c3_core  [                               ■      ■    ]
#     c3_scr   [                               ■      ■    ]
function _zy_dc(sys::CableSystem, metals, T_conductor::T) where {T}
    n = length(metals)
    Z = zeros(Complex{T}, n, n)
    for (i, m) in enumerate(metals)
        Z[i, i] = _R_dc(m.element, T_conductor)
    end
    G = zeros(T, n, n)
    labels = [m.label for m in metals]
    offset = 0
    for c in sys.cables
        offset = _cable_leakage!(G, offset, c.design, labels)
    end
    return Z, complex(G)
end

# Adds the leakage resistors of one cable to G. The conductors of this cable have the
# indices `offset + 1 …`; the function returns the index of the cable's last conductor, which
# is the offset of the next cable. It walks outwards through the layers in the same order as
# `_cable_metals`, so the k-th metallic layer it meets gets the k-th index.
#
# Single-core cable: one chain, core → screen → … → earth, handled by `_walk!`.
#
# Multi-core cable: each core is its own chain up to its outer surface. Those chains end at
# a "tip": the outermost metallic conductor of the core, plus the resistance of the
# non-metallic core layers outside it. All cores then meet at one point just inside the
# common layers (the star point), which connects through the common layers to the first
# metallic common layer, or to earth if there is none. `_star!` adds that star network.
#
# Four-core LV cable (cores without screens, a common PVC jacket):
#
#          ╭──── jacket ────╮          c1_core1 ──[R_a]──╮
#          │   (1)    (2)   │          c1_core2 ──[R_b]──┤
#          │       ✱        │          c1_core3 ──[R_c]──┼── ✱ ──[R_common]── ⏚
#          │   (4)    (3)   │          c1_core4 ──[R_d]──╯
#          ╰────────────────╯
#
#     R_a … R_d: insulation of each core; R_common: the jacket; ✱: the star point.
function _cable_leakage!(G, offset, design::CableDesign, labels)
    R0 = zero(eltype(G))
    k = offset
    tips = Tuple{Int, typeof(R0), Bool}[]
    for core in design.cores
        k += 1
        a, R, insulated, k = _walk!(G, k, R0, false, core.layers, k, labels)
        push!(tips, (a, R, insulated))
    end
    common = design.common_layers
    if length(tips) == 1
        a, R, insulated = only(tips)
        a, R, insulated, k = _walk!(G, a, R, insulated, common, k, labels)
        _connect!(G, a, 0, R, insulated, labels)
        return k
    end
    # Common layers inside the first metallic common layer lie between the star point and
    # that layer (index `o`), or earth (`o = 0`) when the common layers have no metal.
    i_metal = findfirst(_is_metallic, common)
    inner = i_metal === nothing ? common : common[1:(i_metal - 1)]
    R_common = sum(_leakage_resistance, inner; init = R0)
    o = i_metal === nothing ? 0 : (k += 1)
    _star!(G, tips, o, R_common, !isempty(inner), labels)
    if i_metal !== nothing
        a, R, insulated, k = _walk!(G, o, R0, false, common[(i_metal + 1):end], k, labels)
        _connect!(G, a, 0, R, insulated, labels)
    end
    return k
end

# Leakage resistance of one layer per metre of cable [Ω·m].
_leakage_resistance(l::TubularLayer) = l.material.rho * log(l.geom.r_out / l.geom.r_in) / (2 * pi)

# Walks outwards through `layers`, starting at conductor `a` with resistance `R` already
# accumulated outside it. Non-metallic layers add their resistance to `R`. A metallic layer
# gets the next index `k + 1`, is connected to `a` through `R`, and becomes the new `a` with
# `R` reset to zero. `insulated` records whether any non-metallic layer was passed since the
# last metallic one, to catch metallic layers that touch.
#
# Returns the state at the outside of `layers`: the outermost conductor `a`, the resistance
# `R` still pending outside it, `insulated`, and the last index used `k`.
#
# Example, a core with a lead sheath and steel armour:
#
#     conductor | XLPE | lead sheath | PVC | steel armour | PVC | soil
#
#     c1_core ──[R_XLPE]── c1_screen ──[R_PVC]── c1_armour ──[R_PVC]── ⏚
#        #1                   #2                    #3
#
#     layer          a         R          action
#     XLPE           #1        R_XLPE     add to R
#     lead sheath    #1 → #2   0          connect #1–#2, reset R
#     PVC            #2        R_PVC      add to R
#     armour         #2 → #3   0          connect #2–#3, reset R
#     PVC            #3        R_PVC      add to R, returned as pending
#
# The caller then connects #3 to earth through the pending R.
function _walk!(G, a, R, insulated, layers, k, labels)
    for layer in layers
        if _is_metallic(layer)
            k += 1
            _connect!(G, a, k, R, insulated, labels)
            a, R, insulated = k, zero(R), false
        else
            R += _leakage_resistance(layer)
            insulated = true
        end
    end
    return a, R, insulated, k
end

_node_name(labels, b) = b == 0 ? "earth" : string(labels[b])

# Without any insulating layer, two conductors touch and the resistance between them is
# zero, so the conductance would be infinite:
#
#     c1_screen1 ──── c1_screen2      (a lead sheath directly under a wire screen)
#                R = 0  →  g = ∞  →  UnsupportedError
function _check_insulated(insulated, labels, a, other)
    insulated || throw(
        UnsupportedError(
            "compute_ZY: no insulation between $(labels[a]) and $other; the DC leakage " *
                "conductance is infinite",
        ),
    )
    return nothing
end

# Adds a resistor `R` between conductors `a` and `b` to the nodal matrix G: +g on both
# diagonal entries and -g on the two off-diagonal ones, with g = 1/R. When `b = 0` (earth)
# only G[a, a] changes, because earth has no row.
function _connect!(G, a, b, R, insulated, labels)
    _check_insulated(insulated, labels, a, _node_name(labels, b))
    g = inv(R)
    G[a, a] += g
    if b > 0
        G[b, b] += g
        G[a, b] -= g
        G[b, a] -= g
    end
    return nothing
end

# Adds the star network of a multi-core cable. Each tip (a, R, _) is a resistor from core
# conductor `a` to the star point; `R_common` is the resistor from the star point to `o`
# (a metallic common layer, or earth when `o = 0`).
#
# The star point is not a conductor, so it has no row in G and must be eliminated (Kron
# reduction). Before and after, for the four-core cable:
#
#     before: a star, with one extra node ✱        after: a mesh between the cores only
#
#      core1 ──g_a──╮                               core1 ─────── core2
#      core2 ──g_b──┤                                 │ ╲       ╱ │
#      core3 ──g_c──┼── ✱ ──g_common── ⏚              │   ╲   ╱   │     each core also
#      core4 ──g_d──╯                                 │   ╱   ╲   │     has a branch
#                                                   core4 ─────── core3   to ⏚
#
# Derivation. The current into the star point from branch p is g_p (V_p - V_✱), and the
# currents into ✱ sum to zero (nothing else is connected to it):
#
#     Σ_q g_q (V_q - V_✱) = 0    →    V_✱ = Σ_q g_q V_q / S,    S = Σ_q g_q
#
# So the current leaving conductor p is
#
#     I_p = g_p (V_p - V_✱) = g_p V_p - Σ_q (g_p g_q / S) V_q
#
# which gives the nodal entries
#
#     G[p, q] += g_p δ_pq - g_p g_q / S
#
# over all branches p, q, with g = [g_a, g_b, g_c, g_d, g_common]. Earth has V = 0 and no
# row, so its row and column are dropped. With two branches this is the familiar series
# formula g_1 g_2 / (g_1 + g_2).
#
# With four identical cores (g each) and S = 4g + g_common, the block this adds is
#
#                core1        core2        core3        core4
#     core1  [ g - g²/S      -g²/S        -g²/S        -g²/S    ]
#     core2  [  -g²/S      g - g²/S       -g²/S        -g²/S    ]
#     core3  [  -g²/S       -g²/S       g - g²/S       -g²/S    ]
#     core4  [  -g²/S       -g²/S        -g²/S       g - g²/S   ]
#
# The cores are coupled to each other (negative off-diagonal entries), and the sum of all
# entries is 4g·g_common / (4g + g_common): all cores in parallel, in series with the
# jacket. When `o` is a metallic common layer rather than earth, it keeps its row and
# column, which get the g_common terms.
#
# If there is no insulating layer between the cores and `o`, the star point coincides with
# `o`, and each tip is connected straight to it:
#
#      core1 ──g_a──╮
#      core2 ──g_b──┤
#      core3 ──g_c──┼── o   (the first metallic common layer, e.g. an armour)
#      core4 ──g_d──╯
function _star!(G, tips, o, R_common, insulated, labels)
    if !insulated
        for (a, R, ins) in tips
            _connect!(G, a, o, R, ins, labels)
        end
        return nothing
    end
    for (a, _, ins) in tips
        _check_insulated(ins, labels, a, "the common layers")
    end
    nodes = [[a for (a, _, _) in tips]; o]
    g = [[inv(R) for (_, R, _) in tips]; inv(R_common)]
    S = sum(g)
    for p in eachindex(nodes), q in eachindex(nodes)
        nodes[p] > 0 && nodes[q] > 0 || continue
        G[nodes[p], nodes[q]] += (p == q ? g[p] : zero(S)) - g[p] * g[q] / S
    end
    return nothing
end
