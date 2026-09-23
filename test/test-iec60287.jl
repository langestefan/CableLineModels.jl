@testitem "IEC 60287-1-1:2023 Table 1 metals" tags = [:validation] begin
    for (m, rho, alpha) in (
            (COPPER, 1.7241e-8, 3.93e-3),
            (ALUMINIUM, 2.8264e-8, 4.03e-3),
            (LEAD, 21.4e-8, 4.0e-3),
            (STEEL, 13.8e-8, 4.5e-3),
            (ALUMINIUM_SHEATH, 2.84e-8, 4.03e-3),
        )
        @test m.rho == rho && m.alpha == alpha
    end
end

@testitem "IEC 60287-1-1:2023 5.1.2 and 5.3.1 DC resistance" tags = [:validation] setup = [Fixtures] begin
    c = Conductor(RoundSolid(), COPPER; r_out = 5.0e-3, area_nominal = 78.5e-6, R_dc20 = 1.0e-4)
    core = CableCore(
        c, [
            InsulationLayer(5.0e-3, 8.0e-3, XLPE), TubularScreen(8.0e-3, 8.5e-3, LEAD),
            Jacket(8.5e-3, 10.0e-3, PVC),
        ],
    )
    design = CableDesign("demo", core; U0 = 6.35e3)
    sys = CableSystem(PlacedCable(design, 0.0, -1.0, :a); earth = Fixtures.mv_earth(), length = 1.0e3, frequency = 0.0)
    Z = real(compute_ZY(sys, LoopMethod(), 0.0; T_conductor = 90, T_screen = 70).Z[:, :, 1])
    @test Z[1, 1] ≈ 1.2751e-4 rtol = 1.0e-4
    @test Z[2, 2] ≈ 9.9081e-3 rtol = 1.0e-4
end

@testitem "IEC 60287-1-1:2023 Annex A lay-up factor" tags = [:validation] setup = [Fixtures] begin
    d = Fixtures.lv_design()
    laid = CableDesign(d.name, d.cores, FourCoreLV(10.5e-3; lay_length = 0.5); U0 = d.U0, common_layers = d.common_layers)
    sys = CableSystem(PlacedCable(laid, 0.0, -0.7, [:a, :b, :c, :n]); earth = Fixtures.mv_earth(), length = 300.0, frequency = 0.0)
    Z = real(compute_ZY(sys, LoopMethod(), 0.0; T_conductor = 90).Z[:, :, 1])
    @test Z[1, 1] ≈ 2.3374e-4 rtol = 1.0e-4
    @test Z[1, 1] / (COPPER.rho / 95.0e-6 * (1 + COPPER.alpha * 70)) ≈ 1.01007 rtol = 1.0e-5
end
