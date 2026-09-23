@testitem "EarthModel" tags = [:unit] begin
    e = EarthModel(; rho = 100, k_th = 1, T_ambient = 15)
    @test e isa EarthModel{Float64}
    @test e.eps_r == 1 && e.mu_r == 1
    @test EarthModel(; rho = 100.0f0, k_th = 1.0f0, T_ambient = 15.0f0) isa EarthModel{Float32}
    big_e = EarthModel(; rho = big(100), k_th = 1, T_ambient = 15)
    @test big_e == e && hash(big_e) == hash(e)

    @test EarthModel() == e

    @test_throws "rho" EarthModel(; rho = 0, k_th = 1, T_ambient = 15)
    @test_throws "eps_r" EarthModel(; rho = 100, k_th = 1, T_ambient = 15, eps_r = 0.5)
    @test_throws "mu_r" EarthModel(; rho = 100, k_th = 1, T_ambient = 15, mu_r = 0.5)
    @test_throws "k_th" EarthModel(; rho = 100, k_th = 0, T_ambient = 15)
    @test_throws "T_ambient" EarthModel(; rho = 100, k_th = 1, T_ambient = NaN)
end

@testitem "Bonding" tags = [:unit] begin
    @test CrossBonded(2).n_major == 2
    @test_throws ArgumentError CrossBonded(0)
end

@testitem "PlacedCable" tags = [:unit] setup = [Fixtures] begin
    d = Fixtures.mv_design()
    c = PlacedCable(d, 0, -1, :a)
    @test c isa PlacedCable{Float64}
    @test c.phases == [:a] && outer_radius(c) == outer_radius(d)
    @test c.design === d
    @test PlacedCable(d, 0.0f0, -1.0f0, [:a]) isa PlacedCable{Float32}

    lv = Fixtures.lv_design()
    @test PlacedCable(lv, 0.0, -0.7, [:a, :b, :c, :n]).phases == [:a, :b, :c, :n]
    @test_throws "has 4 core(s), got 1 phase(s)" PlacedCable(lv, 0.0, -0.7, :a)
    @test_throws "has 1 core(s), got 2" PlacedCable(d, 0.0, -1.0, [:a, :b])
    @test_throws "x must be finite" PlacedCable(d, Inf, -1.0, :a)
end

@testitem "CableSystem construction" tags = [:unit] setup = [Fixtures] begin
    sys = Fixtures.mv_system()
    @test sys isa CableSystem{Float64} && sys.bonding == BothEnds()
    @test length(sys.cables) == 3
    @test sys == Fixtures.mv_system() && hash(sys) == hash(Fixtures.mv_system())
    @test sys != Fixtures.mv_system(; bonding = SinglePoint())
    @test Fixtures.mv_system(; bonding = CrossBonded(3)).bonding == CrossBonded(3)
    @test Fixtures.mv_system(; frequency = 0.0).frequency == 0

    c = PlacedCable(Fixtures.lv_design(), 0.0, -0.7, [:a, :b, :c, :n])
    lv = CableSystem(c; earth = Fixtures.mv_earth(), length = 300.0, frequency = 50.0)
    @test lv isa CableSystem{Float64}
    @test CableSystem(c; earth = Fixtures.mv_earth(), length = 300.0f0, frequency = 50.0f0) isa CableSystem{Float32}
end

@testitem "Trefoil and system defaults" tags = [:unit] setup = [Fixtures] begin
    d = Fixtures.mv_design()
    cables = trefoil(d; depth = 1.2)
    @test [only(c.phases) for c in cables] == [:a, :b, :c]
    @test cables[1].y == cables[2].y == -1.2
    r = outer_radius(d)
    dist(a, b) = hypot(a.x - b.x, a.y - b.y)
    @test dist(cables[1], cables[2]) ≈ 2r && dist(cables[1], cables[3]) ≈ 2r && dist(cables[2], cables[3]) ≈ 2r

    sys = CableSystem(trefoil(d))
    @test sys.earth == EarthModel() && sys.length == 1.0e3 && sys.frequency == 50
    @test sys.bonding == BothEnds()
    @test_throws "has 4 core(s)" trefoil(Fixtures.lv_design())
end

@testitem "System display" tags = [:unit] setup = [Fixtures] begin
    @test occursin("T_ambient = 15.0 °C", repr("text/plain", EarthModel()))
    txt = repr("text/plain", Fixtures.mv_system())
    @test startswith(txt, "CableSystem{Float64}: 3 cables, 5000.0 m, 50.0 Hz, BothEnds()")
    @test occursin("cable 1: \"MV 1x240 Al 12/20 kV\" at (", txt) && occursin("phases c", txt)
end

@testitem "CableSystem validation" tags = [:unit] setup = [Fixtures] begin
    d = Fixtures.mv_design()
    r = outer_radius(d)
    earth = Fixtures.mv_earth()
    sys(cables; kw...) = CableSystem(cables; earth, length = 1.0e3, frequency = 50.0, kw...)

    @test_throws "length" Fixtures.mv_system(; length = 0.0)
    @test_throws "length" Fixtures.mv_system(; length = Inf)
    @test_throws "frequency" Fixtures.mv_system(; frequency = -50.0)
    @test_throws "at least one cable" sys(PlacedCable{Float64}[])

    @test_throws "cable 1 reaches above ground" sys(PlacedCable(d, 0.0, -r / 2, :a))
    @test sys(PlacedCable(d, 0.0, -2r, :a)) isa CableSystem
    @test_throws "cables 1 and 2 overlap" sys([PlacedCable(d, 0.0, -1.0, :a), PlacedCable(d, r, -1.0, :b)])
    @test sys([PlacedCable(d, 0.0, -1.0, :a), PlacedCable(d, 2r, -1.0, :b)]) isa CableSystem
end

@testitem "CableSystem with dual numbers" tags = [:ad] setup = [Fixtures] begin
    using ForwardDiff: ForwardDiff
    sys = Fixtures.mv_system(ForwardDiff.Dual(9.1e-3, 1.0))
    @test sys.cables[2].x isa ForwardDiff.Dual
    @test ForwardDiff.derivative(r -> Fixtures.mv_system(r).cables[2].x, 9.1e-3) ≈ 1
end

@testitem "CableSystem with uncertain numbers" tags = [:uncertainty] setup = [Fixtures] begin
    using Measurements: measurement, Measurement
    import MonteCarloMeasurements as MCM

    @test Fixtures.mv_system(measurement(9.1e-3, 0.05e-3)).cables[1].x isa Measurement
    sys = Fixtures.mv_system(MCM.Particles(200, MCM.Normal(9.1e-3, 0.05e-3)))
    @test sys.cables[1].x isa MCM.Particles

    k_th = MCM.Particles(200, MCM.Uniform(0.7, 1.5))
    e = EarthModel(; rho = 100.0, k_th, T_ambient = 15.0)
    @test e isa EarthModel{<:MCM.Particles}
end
