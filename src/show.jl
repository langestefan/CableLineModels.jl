_compact(io, x) = show(IOContext(io, :compact => true), x)
_unqualified(io, x) = show(IOContext(io, :module => @__MODULE__), x)

function _properties(io, rows)
    for (label, x, unit) in rows
        print(io, "\n  ", rpad(label, 10), "= ", x, unit)
    end
    return nothing
end

Base.show(io::IO, m::Material) = print(io, "Material(\"", m.name, "\")")

function Base.show(io::IO, ::MIME"text/plain", m::Material{T}) where {T}
    print(io, "Material{", T, "} \"", m.name, "\"")
    return _properties(
        io, (
            ("rho", m.rho, " Ω·m"), ("alpha", m.alpha, " 1/K"), ("eps_r", m.eps_r, ""),
            ("mu_r", m.mu_r, ""), ("tan_delta", m.tan_delta, ""), ("k_th", m.k_th, " K·m/W"),
        ),
    )
end

function Base.show(io::IO, ::MIME"text/plain", e::EarthModel{T}) where {T}
    print(io, "EarthModel{", T, "}")
    return _properties(
        io, (
            ("rho", e.rho, " Ω·m"), ("eps_r", e.eps_r, ""), ("mu_r", e.mu_r, ""),
            ("k_th", e.k_th, " K·m/W"), ("T_ambient", e.T_ambient, " °C"),
        ),
    )
end

function _layer_row(io, indent, kind, material, r_in, r_out)
    print(io, "\n", indent, rpad(kind, 16), rpad(material.name, 18))
    _compact(io, r_in * 1000)
    print(io, " – ")
    _compact(io, r_out * 1000)
    return print(io, " mm")
end

function _layer_rows(io, indent, layers)
    for l in layers
        _layer_row(io, indent, nameof(typeof(l)), l.material, inner_radius(l), outer_radius(l))
        l isa WireLayer && print(io, ", ", l.geom.n_wires, " wires")
    end
    return nothing
end

function _core_rows(io, indent, core::CableCore)
    c = core.conductor
    _layer_row(io, indent, "Conductor", c.material, c.r_in, c.r_out)
    print(io, ", ")
    _compact(io, c.area_nominal * 1.0e6)
    print(io, " mm²")
    return _layer_rows(io, indent, core.layers)
end

function Base.show(io::IO, ::MIME"text/plain", core::CableCore)
    print(io, "CableCore, radii inside-out:")
    return _core_rows(io, "  ", core)
end

Base.show(io::IO, d::CableDesign) = print(io, "CableDesign(\"", d.name, "\")")

function Base.show(io::IO, ::MIME"text/plain", d::CableDesign)
    print(io, "CableDesign \"", d.name, "\"\n  ", uppercase(string(d.system_type)), ", U0 = ")
    _compact(io, d.U0 / 1000)
    print(io, " kV, ")
    _unqualified(io, d.layout)
    print(io, ", outer radius ")
    _compact(io, outer_radius(d) * 1000)
    print(io, " mm")
    n = length(d.cores)
    if allequal(d.cores)
        print(io, "\n  ", n == 1 ? "core" : "each of $n cores", ":")
        _core_rows(io, "    ", first(d.cores))
    else
        for (i, core) in enumerate(d.cores)
            print(io, "\n  core ", i, ":")
            _core_rows(io, "    ", core)
        end
    end
    if !isempty(d.common_layers)
        print(io, "\n  common layers:")
        _layer_rows(io, "    ", d.common_layers)
    end
    return nothing
end

function Base.show(io::IO, ::MIME"text/plain", sys::CableSystem{T}) where {T}
    n = length(sys.cables)
    print(io, "CableSystem{", T, "}: ", n, n == 1 ? " cable, " : " cables, ")
    print(io, sys.length, " m, ", sys.frequency, " Hz, ")
    _unqualified(io, sys.bonding)
    print(io, "\n  earth: rho = ", sys.earth.rho, " Ω·m, k_th = ", sys.earth.k_th)
    print(io, " K·m/W, T_ambient = ", sys.earth.T_ambient, " °C")
    for (i, c) in enumerate(sys.cables)
        print(io, "\n  cable ", i, ": \"", c.design.name, "\" at (")
        _compact(io, c.x)
        print(io, ", ")
        _compact(io, c.y)
        print(io, ") m, phases ", join(c.phases, ", "))
    end
    return nothing
end

function Base.show(io::IO, ::MIME"text/plain", zy::ZYData{T}) where {T}
    n, nf = length(zy.labels), length(zy.freqs)
    print(io, "ZYData{", T, "}: ", n, " conductors, ", nf, nf == 1 ? " frequency" : " frequencies")
    print(io, ", cores at ", zy.T_conductor, " °C, screens at ", zy.T_screen, " °C")
    print(io, "\n  self impedance at ", zy.freqs[1], " Hz", nf > 1 ? " (first frequency)" : "", " [Ω/km]:")
    z = [zy.Z[i, i, 1] * 1000 for i in 1:n]
    values = all(iszero ∘ imag, z) ? real(z) : z
    for (label, v) in zip(zy.labels, values)
        print(io, "\n    ", rpad(label, 12))
        _compact(io, v)
    end
    return nothing
end
