@testmodule Fixtures begin
    using CableLineModels

    function mv_core(r_c = 9.1e-3)
        conductor = Conductor(RoundStranded(37), ALUMINIUM; r_out = r_c, area_nominal = 240.0e-6)
        r = (r_c, r_c + 0.5e-3, r_c + 6.0e-3, r_c + 6.5e-3)
        wire_mean = r[4] + 0.6e-3
        return CableCore(
            conductor, [
                SemiconLayer(r[1], r[2]),
                InsulationLayer(r[2], r[3], XLPE),
                SemiconLayer(r[3], r[4]),
                WireScreen(wire_mean, 40, 0.45e-3, 0.2, COPPER),
                Jacket(wire_mean + 0.45e-3, wire_mean + 2.95e-3, PVC),
            ],
        )
    end

    mv_design(r_c = 9.1e-3) = CableDesign("MV 1x240 Al 12/20 kV", mv_core(r_c); U0 = 12.0e3)

    function lv_design()
        conductor = Conductor(RoundStranded(19), COPPER; r_out = 5.8e-3, area_nominal = 95.0e-6)
        core = CableCore(conductor, [InsulationLayer(5.8e-3, 7.4e-3, PVC)])
        return CableDesign(
            "LV 4x95 Cu 0.6/1 kV", fill(core, 4), FourCoreLV(10.5e-3);
            U0 = 0.6e3, common_layers = [Jacket(18.2e-3, 20.2e-3, PVC)],
        )
    end

    mv_earth() = EarthModel(; rho = 100.0, k_th = 1.0, T_ambient = 15.0)

    function mv_system(r_c = 9.1e-3; depth = 1.0, kwargs...)
        d = mv_design(r_c)
        r = outer_radius(d)
        centres = ((-r, -depth), (r, -depth), (zero(r), -depth + sqrt(3) * r))
        cables = [PlacedCable(d, x, y, p) for ((x, y), p) in zip(centres, (:a, :b, :c))]
        return CableSystem(cables; earth = mv_earth(), length = 5.0e3, frequency = 50.0, kwargs...)
    end
end
