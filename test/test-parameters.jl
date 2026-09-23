@testitem "Parameter methods and ZYData" tags = [:unit] begin
    @test LoopMethod().earth == :wedepohl
    @test LoopMethod(:pollaczek).earth == :pollaczek
    @test_throws "earth must be :wedepohl or :pollaczek" LoopMethod(:carson)

    Z = zeros(ComplexF64, 2, 2, 1)
    zy = ZYData([0.0], Z, Z, [:a, :b], 90)
    @test zy isa ZYData{Float64} && numtype(zy) == Float64
    @test zy == ZYData([0.0], Z, Z, [:a, :b], 90.0)
    @test_throws "must be 2×2×1" ZYData([0.0], Z, zeros(ComplexF64, 2, 2, 2), [:a, :b], 90)
    @test_throws "labels must be unique" ZYData([0.0], Z, Z, [:a, :a], 90)
end

@testitem "compute_ZY at DC" tags = [:unit] setup = [Fixtures] begin
    sys = Fixtures.mv_system()
    zy = compute_ZY(sys, LoopMethod(), 0.0)
    @test zy isa ZYData{Float64}
    @test zy.labels == [:c1_core, :c1_screen, :c2_core, :c2_screen, :c3_core, :c3_screen]
    @test size(zy.Z) == size(zy.Y) == (6, 6, 1)
    @test zy.T_conductor == 90 && zy.freqs == [0]

    Z = real(zy.Z[:, :, 1])
    Y = real(zy.Y[:, :, 1])
    @test Z[1:2, 1:2] == Z[3:4, 3:4] == Z[5:6, 5:6]
    @test all(iszero, imag(zy.Z)) && all(iszero, imag(zy.Y))
    @test Z[1, 1] ≈ ALUMINIUM.rho / 240.0e-6 * (1 + ALUMINIUM.alpha * 70)
    @test Z[2, 2] ≈ COPPER.rho / (40 * pi * 0.45e-3^2) * (1 + COPPER.alpha * 70)
    @test count(!iszero, Z) == 6

    r = 9.1e-3 .+ (0.0, 0.5e-3, 6.0e-3, 6.5e-3)
    G_ins = 2pi / (SEMICON.rho * log(r[2] / r[1]) + XLPE.rho * log(r[3] / r[2]) + SEMICON.rho * log(r[4] / r[3]))
    wire_mean = r[4] + 0.6e-3
    G_jacket = 2pi / (PVC.rho * log((wire_mean + 2.95e-3) / (wire_mean + 0.45e-3)))
    @test Y[1:2, 1:2] ≈ [G_ins -G_ins; -G_ins G_ins + G_jacket]
    @test Y ≈ permutedims(Y) && iszero(Y[1:2, 3:6])

    @test real(compute_ZY(sys, LoopMethod(), 0.0; T_conductor = 20).Z[1, 1, 1]) ≈ ALUMINIUM.rho / 240.0e-6
    @test compute_ZY(sys, IEC60287Method(), [0, 0]).Z[:, :, 2] == zy.Z[:, :, 1]
    @test @inferred(compute_ZY(sys, LoopMethod(), 0.0)) isa ZYData{Float64}
end

@testitem "compute_ZY at DC, four-core cable" tags = [:unit] setup = [Fixtures] begin
    c = PlacedCable(Fixtures.lv_design(), 0.0, -0.7, [:a, :b, :c, :n])
    sys = CableSystem(c; earth = Fixtures.mv_earth(), length = 300.0, frequency = 50.0)
    zy = compute_ZY(sys, LoopMethod(), 0.0)
    @test zy.labels == [:c1_core1, :c1_core2, :c1_core3, :c1_core4]
    Y = real(zy.Y[:, :, 1])
    @test Y ≈ permutedims(Y) && all(<(0), Y[2:4, 1])
    G_core = 2pi / (PVC.rho * log(7.4 / 5.8))
    G_jacket = 2pi / (PVC.rho * log(20.2 / 18.2))
    @test sum(Y) ≈ inv(inv(4G_core) + inv(G_jacket))
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
    @test Z[3, 3] ≈ STEEL.rho / (20 * pi * 0.5e-3^2)
    Y = real(zy.Y[:, :, 1])
    @test Y[1, 3] == 0 && Y[2, 3] < 0 && sum(Y) ≈ 2pi / (PVC.rho * log(11 / 10))

    @test CableLineModels._rho_eq(c) ≈ 2.2e-4 * pi * 5.0e-3^2
end

@testitem "compute_ZY errors" tags = [:unit] setup = [Fixtures] begin
    sys = Fixtures.mv_system()
    @test_throws "pending IEC 60287-1-1" compute_ZY(sys, IEC60287Method(), 50.0)
    @test_throws UnsupportedError compute_ZY(sys, LoopMethod(), [0.0, 50.0])
    @test_throws "must not be empty" compute_ZY(sys, LoopMethod(), Float64[])
    @test_throws "finite and ≥ 0" compute_ZY(sys, LoopMethod(), -50.0)
    @test_throws "finite and ≥ 0" compute_ZY(sys, LoopMethod(), NaN)
    @test_throws "T_conductor must be finite" compute_ZY(sys, LoopMethod(), 0.0; T_conductor = Inf)
    @test_throws "not positive at" compute_ZY(sys, LoopMethod(), 0.0; T_conductor = -300)

    c = Conductor(RoundSolid(), COPPER; r_out = 5.0e-3, area_nominal = 78.5e-6)
    earth = Fixtures.mv_earth()
    function system(layers)
        design = CableDesign("demo", CableCore(c, layers); U0 = 6.35e3)
        return CableSystem(PlacedCable(design, 0.0, -1.0, :a); earth, length = 1.0e3, frequency = 0.0)
    end
    bare = system([InsulationLayer(5.0e-3, 8.0e-3, XLPE), TubularScreen(8.0e-3, 8.5e-3, LEAD)])
    @test_throws "no insulation between c1_screen and earth" compute_ZY(bare, LoopMethod(), 0.0)
    touching = system(
        [
            InsulationLayer(5.0e-3, 8.0e-3, XLPE), TubularScreen(8.0e-3, 8.5e-3, LEAD),
            WireScreen(8.9e-3, 30, 0.4e-3, 0.2, COPPER), Jacket(9.3e-3, 10.0e-3, PVC),
        ],
    )
    @test_throws "no insulation between c1_screen1 and c1_screen2" compute_ZY(touching, LoopMethod(), 0.0)
end

@testitem "compute_ZY number types" tags = [:unit] setup = [Fixtures] begin
    sys32 = CableSystem{Float32}(Fixtures.mv_system())
    @test compute_ZY(sys32, LoopMethod(), 0.0f0) isa ZYData{Float32}
    @test compute_ZY(sys32, LoopMethod(), 0.0) isa ZYData{Float64}
    zy = compute_ZY(Fixtures.mv_system(), LoopMethod(), 0.0; T_conductor = big(90))
    @test zy isa ZYData{BigFloat}
    @test zy.Z ≈ compute_ZY(Fixtures.mv_system(), LoopMethod(), 0.0).Z
end

@testitem "compute_ZY with dual numbers" tags = [:ad] setup = [Fixtures] begin
    using ForwardDiff: ForwardDiff
    sys = Fixtures.mv_system()
    R(t) = real(compute_ZY(sys, LoopMethod(), 0.0; T_conductor = t).Z[1, 1, 1])
    @test ForwardDiff.derivative(R, 90.0) ≈ ALUMINIUM.rho / 240.0e-6 * ALUMINIUM.alpha

    G(r_c) = real(compute_ZY(Fixtures.mv_system(r_c), LoopMethod(), 0.0).Y[1, 1, 1])
    h = 1.0e-9
    @test ForwardDiff.derivative(G, 9.1e-3) ≈ (G(9.1e-3 + h) - G(9.1e-3 - h)) / 2h rtol = 1.0e-5
end

@testitem "compute_ZY with uncertain numbers" tags = [:uncertainty] setup = [Fixtures] begin
    using Measurements: measurement, Measurement
    import MonteCarloMeasurements as MCM

    zy = compute_ZY(Fixtures.mv_system(measurement(9.1e-3, 0.05e-3)), LoopMethod(), 0.0)
    @test numtype(zy) <: Measurement

    T_c = MCM.Particles(200, MCM.Uniform(60.0, 90.0))
    zy = compute_ZY(Fixtures.mv_system(), LoopMethod(), 0.0; T_conductor = T_c)
    @test numtype(zy) <: MCM.Particles
    @test MCM.pmean(real(zy.Z[1, 1, 1])) < real(compute_ZY(Fixtures.mv_system(), LoopMethod(), 0.0).Z[1, 1, 1])
end
