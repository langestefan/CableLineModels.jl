_area(g::Annulus) = pi * (g.r_out^2 - g.r_in^2)
_area(g::WireGeometry) = g.n_wires * pi * g.r_wire^2

_R_dc20(c::Conductor) = something(c.R_dc20, c.material.rho / c.area_nominal)
_R_dc20(l::TubularScreen) = l.material.rho / _area(l.geom)
_R_dc20(l::WireLayer) = l.material.rho / _area(l.geom) * _lay_factor(l.geom)

_lay_factor(g::WireGeometry) = sqrt(1 + (2 * pi * g.r_mean / g.lay_length)^2)

_material(c::Conductor) = c.material
_material(l::Layer) = l.material

_temperature(::Conductor, T_conductor, _) = T_conductor
_temperature(::Layer, _, T_screen) = T_screen

function _R_dc(x, T_conductor, T_screen)
    T = _temperature(x, T_conductor, T_screen)
    k = 1 + _material(x).alpha * (T - 20)
    k > 0 || throw(
        ArgumentError("compute_ZY: resistance of $(_material(x).name) is not positive at $T °C"),
    )
    return _R_dc20(x) * k
end

_rho_eq(c::Conductor) = _R_dc20(c) * pi * (c.r_out^2 - c.r_in^2)
