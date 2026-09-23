_area(g::Annulus) = pi * (g.r_out^2 - g.r_in^2)
_area(g::WireGeometry) = g.n_wires * pi * g.r_wire^2

_R_dc20(c::Conductor) = something(c.R_dc20, c.material.rho / c.area_nominal)
_R_dc20(l::Union{TubularScreen, WireLayer}) = l.material.rho / _area(geometry(l))

_material(c::Conductor) = c.material
_material(l::Layer) = l.material

function _temperature_factor(x, T_conductor)
    k = 1 + _material(x).alpha * (T_conductor - 20)
    k > 0 || throw(
        ArgumentError(
            "compute_ZY: resistance of $(_material(x).name) is not positive at $T_conductor °C",
        ),
    )
    return k
end

_R_dc(x, T_conductor) = _R_dc20(x) * _temperature_factor(x, T_conductor)

_rho_eq(c::Conductor) = _R_dc20(c) * pi * (c.r_out^2 - c.r_in^2)
