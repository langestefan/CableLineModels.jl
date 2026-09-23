@testitem "Parameter methods and ZYData" tags = [:unit] begin
    @test LoopMethod().earth == :wedepohl
    @test LoopMethod(:pollaczek).earth == :pollaczek
    @test_throws "earth must be :wedepohl or :pollaczek" LoopMethod(:carson)

    Z = zeros(ComplexF64, 2, 2, 1)
    zy = ZYData([0.0], Z, Z, [:a, :b], 90, 70)
    @test zy isa ZYData{Float64}
    @test zy == ZYData([0.0], Z, Z, [:a, :b], 90.0, 70.0)
    @test_throws "must be 2×2×1" ZYData([0.0], Z, zeros(ComplexF64, 2, 2, 2), [:a, :b], 90, 70)
    @test_throws "labels must be unique" ZYData([0.0], Z, Z, [:a, :a], 90, 70)

    Z[1, 1, 1] = 1.0e-4
    shown = repr("text/plain", ZYData([0.0], Z, Z, [:a, :b], 90, 70))
    @test startswith(shown, "ZYData{Float64}: 2 conductors, 1 frequency, cores at 90.0 °C, screens at 70.0 °C")
    @test occursin("at 0.0 Hz [Ω/km]:\n    a           0.1\n    b           0.0", shown)
    Zac = fill(1.0e-4 + 2.0e-4im, 2, 2, 2)
    shown = repr("text/plain", ZYData([50.0, 100.0], Zac, Zac, [:a, :b], 90, 70))
    @test occursin("2 frequencies", shown) && occursin("50.0 Hz (first frequency)", shown)
    @test occursin("0.1+0.2im", shown)
end

@testitem "compute_ZY at DC" tags = [:unit] setup = [Fixtures] begin
    sys = Fixtures.mv_system()
    zy = compute_ZY(sys, LoopMethod(), 0.0)
    @test zy isa ZYData{Float64}
    @test zy.labels == [:c1_core, :c1_screen, :c2_core, :c2_screen, :c3_core, :c3_screen]
    @test size(zy.Z) == size(zy.Y) == (6, 6, 1)
    @test zy.T_conductor == 90 && zy.freqs == [0]

    Z = real(zy.Z[:, :, 1])
    @test Z[1:2, 1:2] == Z[3:4, 3:4] == Z[5:6, 5:6]
    @test all(iszero, imag(zy.Z)) && all(iszero, zy.Y)
    @test Z[1, 1] ≈ ALUMINIUM.rho / 240.0e-6 * (1 + ALUMINIUM.alpha * 70)
    lay = sqrt(1 + (2pi * 16.2e-3 / 0.2)^2)
    @test Z[2, 2] ≈ COPPER.rho / (40 * pi * 0.45e-3^2) * lay * (1 + COPPER.alpha * 70)
    zy_cool = compute_ZY(sys, LoopMethod(), 0.0; T_screen = 65)
    @test zy_cool.T_screen == 65 && zy_cool.Z[1, 1, 1] == zy.Z[1, 1, 1]
    @test real(zy_cool.Z[2, 2, 1]) ≈ COPPER.rho / (40 * pi * 0.45e-3^2) * lay * (1 + COPPER.alpha * 45)
    @test count(!iszero, Z) == 6

    @test real(compute_ZY(sys, LoopMethod(), 0.0; T_conductor = 20).Z[1, 1, 1]) ≈ ALUMINIUM.rho / 240.0e-6
    @test compute_ZY(sys, IEC60287Method(), [0, 0]).Z[:, :, 2] == zy.Z[:, :, 1]
end

@testitem "compute_ZY at DC, four-core cable" tags = [:unit] setup = [Fixtures] begin
    c = PlacedCable(Fixtures.lv_design(), 0.0, -0.7, [:a, :b, :c, :n])
    sys = CableSystem(c; earth = Fixtures.mv_earth(), length = 300.0, frequency = 50.0)
    zy = compute_ZY(sys, LoopMethod(), 0.0)
    @test zy.labels == [:c1_core1, :c1_core2, :c1_core3, :c1_core4]
    R_straight = COPPER.rho / 95.0e-6 * (1 + COPPER.alpha * 70)
    @test real(zy.Z[4, 4, 1]) ≈ R_straight

    d = Fixtures.lv_design()
    laid = CableDesign(d.name, d.cores, FourCoreLV(10.5e-3; lay_length = 0.5); U0 = d.U0, common_layers = d.common_layers)
    sys_laid = CableSystem(PlacedCable(laid, 0.0, -0.7, [:a, :b, :c, :n]); earth = Fixtures.mv_earth(), length = 300.0, frequency = 50.0)
    C_LL = sqrt(1 + (pi * 1.53 * 14.8e-3 / 0.5)^2)
    @test real(compute_ZY(sys_laid, LoopMethod(), 0.0).Z[4, 4, 1]) ≈ R_straight * C_LL
end

@testitem "compute_ZY with a sheath and armour" tags = [:unit] begin
    c = Conductor(RoundSolid(), COPPER; r_out = 5.0e-3, area_nominal = 78.5e-6, R_dc20 = 2.2e-4)
    core = CableCore(
        c, [
            InsulationLayer(5.0e-3, 8.0e-3, XLPE), TubularScreen(8.0e-3, 8.5e-3, LEAD),
            Jacket(8.5e-3, 9.0e-3, PVC), Armour(9.5e-3, 20, 0.5e-3, 0.3, STEEL),
            Jacket(10.0e-3, 11.0e-3, PVC),
        ],
    )
    earth = EarthModel(; rho = 100.0, k_th = 1.0, T_ambient = 15.0)
    sys = CableSystem(
        PlacedCable(CableDesign("demo", core; U0 = 6.35e3), 0.0, -1.0, :a);
        earth, length = 1.0e3, frequency = 50.0,
    )
    zy = compute_ZY(sys, LoopMethod(), 0.0; T_conductor = 20.0)
    @test zy.labels == [:c1_core, :c1_screen, :c1_armour]
    Z = real(zy.Z[:, :, 1])
    @test Z[1, 1] == 2.2e-4
    @test Z[2, 2] ≈ LEAD.rho / (pi * (8.5e-3^2 - 8.0e-3^2))
    @test Z[3, 3] ≈ STEEL.rho / (20 * pi * 0.5e-3^2) * sqrt(1 + (2pi * 9.5e-3 / 0.3)^2)

    @test CableLineModels._rho_eq(c) ≈ 2.2e-4 * pi * 5.0e-3^2
end

@testitem "compute_ZY errors" tags = [:unit] setup = [Fixtures] begin
    sys = Fixtures.mv_system()
    @test_throws "IEC60287Method at f > 0 is not implemented yet" compute_ZY(sys, IEC60287Method(), 50.0)
    @test_throws UnsupportedError compute_ZY(sys, LoopMethod(), [0.0, 50.0])
    @test_throws "must not be empty" compute_ZY(sys, LoopMethod(), Float64[])
    @test_throws "finite and ≥ 0" compute_ZY(sys, LoopMethod(), -50.0)
    @test_throws "finite and ≥ 0" compute_ZY(sys, LoopMethod(), NaN)
    @test_throws "T_conductor must be finite" compute_ZY(sys, LoopMethod(), 0.0; T_conductor = Inf)
    @test_throws "T_screen must be finite" compute_ZY(sys, LoopMethod(), 0.0; T_screen = NaN)
    @test_throws "not positive at" compute_ZY(sys, LoopMethod(), 0.0; T_conductor = -300)
end

@testitem "compute_ZY number types" tags = [:unit] setup = [Fixtures] begin
    @test compute_ZY(Fixtures.mv_system(), LoopMethod(), 0.0f0) isa ZYData{Float64}
    zy = compute_ZY(Fixtures.mv_system(), LoopMethod(), 0.0; T_conductor = big(90))
    @test zy isa ZYData{BigFloat}
    @test zy.Z ≈ compute_ZY(Fixtures.mv_system(), LoopMethod(), 0.0).Z
end

@testitem "compute_ZY with dual numbers" tags = [:ad] setup = [Fixtures] begin
    using ForwardDiff: ForwardDiff
    sys = Fixtures.mv_system()
    R(t) = real(compute_ZY(sys, LoopMethod(), 0.0; T_conductor = t).Z[1, 1, 1])
    @test ForwardDiff.derivative(R, 90.0) ≈ ALUMINIUM.rho / 240.0e-6 * ALUMINIUM.alpha

    @test compute_ZY(sys, LoopMethod(), 0.0; T_conductor = ForwardDiff.Dual(90.0, 1.0)) isa ZYData{<:ForwardDiff.Dual}
end

@testitem "compute_ZY with uncertain numbers" tags = [:uncertainty] setup = [Fixtures] begin
    using Measurements: measurement, Measurement
    import MonteCarloMeasurements as MCM

    zy = compute_ZY(Fixtures.mv_system(), LoopMethod(), 0.0; T_conductor = measurement(90.0, 5.0))
    @test zy isa ZYData{<:Measurement}

    T_c = MCM.Particles(200, MCM.Uniform(60.0, 90.0))
    zy = compute_ZY(Fixtures.mv_system(), LoopMethod(), 0.0; T_conductor = T_c)
    @test zy isa ZYData{<:MCM.Particles}
    @test MCM.pmean(real(zy.Z[1, 1, 1])) < real(compute_ZY(Fixtures.mv_system(), LoopMethod(), 0.0).Z[1, 1, 1])
end
