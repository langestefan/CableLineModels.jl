@testitem "EarthModel" tags = [:unit] begin
    e = EarthModel(; rho = 100, k_th = 1, T_ambient = 15)
    @test e isa EarthModel{Float64}
    @test e.eps_r == 1 && e.mu_r == 1
    @test EarthModel(; rho = 100.0f0, k_th = 1.0f0, T_ambient = 15.0f0) isa EarthModel{Float32}
    @test EarthModel{BigFloat}(e) == e && hash(EarthModel{BigFloat}(e)) == hash(e)
    @test @inferred(EarthModel(; rho = 100.0, k_th = 1.0, T_ambient = 15.0)) isa EarthModel{Float64}

    @test_throws "rho" EarthModel(; rho = 0, k_th = 1, T_ambient = 15)
    @test_throws "eps_r" EarthModel(; rho = 100, k_th = 1, T_ambient = 15, eps_r = 0.5)
    @test_throws "mu_r" EarthModel(; rho = 100, k_th = 1, T_ambient = 15, mu_r = 0.5)
    @test_throws "k_th" EarthModel(; rho = 100, k_th = 0, T_ambient = 15)
    @test_throws "T_ambient" EarthModel(; rho = 100, k_th = 1, T_ambient = NaN)
end

@testitem "Installation and bonding" tags = [:unit] begin
    @test InDuct(0.05, 0.06) isa InDuct{Float64}
    @test InDuct{BigFloat}(0.05, 0.06) == InDuct(0.05, 0.06)
    @test_throws "InDuct: need 0 < r_in < r_out" InDuct(0.06, 0.05)
    @test CrossBonded(2).n_major == 2
    @test_throws ArgumentError CrossBonded(0)
end

@testitem "PlacedCable" tags = [:unit] setup = [Fixtures] begin
    d = Fixtures.mv_design()
    c = PlacedCable(d, 0, -1, :a)
    @test c isa PlacedCable{Float64}
    @test c.phases == [:a] && outer_radius(c) == outer_radius(d)
    @test c.design === d
    @test PlacedCable(d, 0.0f0, -1.0f0, [:a]) isa PlacedCable{Float64}
    @test PlacedCable{BigFloat}(c) == c

    lv = Fixtures.lv_design()
    @test PlacedCable(lv, 0.0, -0.7, (:a, :b, :c, :n)).phases == [:a, :b, :c, :n]
    @test_throws "has 4 core(s), got 1 phase(s)" PlacedCable(lv, 0.0, -0.7, :a)
    @test_throws "has 1 core(s), got 2" PlacedCable(d, 0.0, -1.0, [:a, :b])
    @test_throws "x must be finite" PlacedCable(d, Inf, -1.0, :a)
    @test @inferred(PlacedCable(d, 0.0, -1.0, :a)) isa PlacedCable{Float64}
end

@testitem "CableSystem construction" tags = [:unit] setup = [Fixtures] begin
    sys = Fixtures.mv_system()
    @test sys isa CableSystem{Float64, DirectBuried, BothEnds}
    @test length(sys.cables) == 3 && isempty(sys.compensation)
    @test numtype(sys) == Float64
    @test sys == Fixtures.mv_system() && hash(sys) == hash(Fixtures.mv_system())
    @test sys != Fixtures.mv_system(; bonding = SinglePoint())
    @test Fixtures.mv_system(; bonding = CrossBonded(3)).bonding == CrossBonded(3)
    @test Fixtures.mv_system(; frequency = 0.0).frequency == 0
    @test CableSystem{BigFloat}(sys) == sys

    c = PlacedCable(Fixtures.lv_design(), 0.0, -0.7, [:a, :b, :c, :n])
    lv = CableSystem(c; earth = Fixtures.mv_earth(), length = 300.0, frequency = 50.0)
    @test lv isa CableSystem{Float64}
    @test @inferred(CableSystem([c]; earth = Fixtures.mv_earth(), length = 300.0, frequency = 50.0)) isa CableSystem

    e32 = EarthModel{Float32}(Fixtures.mv_earth())
    @test CableSystem(c; earth = e32, length = 300.0f0, frequency = 50.0f0) isa CableSystem{Float64}
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

    duct = InDuct(r + 1.0e-3, r + 5.0e-3)
    cables = [PlacedCable(d, 0.0, -1.0, :a), PlacedCable(d, 2r, -1.0, :b)]
    @test_throws "cables 1 and 2 overlap" sys(cables; installation = duct)
    ducted = sys([PlacedCable(d, 0.0, -1.0, :a), PlacedCable(d, 0.1, -1.0, :b)]; installation = duct)
    @test ducted isa CableSystem{Float64, InDuct{Float64}}
    @test_throws "does not fit in a duct" sys(cables; installation = InDuct(r / 2, 2r))
    @test_throws "above ground" sys(PlacedCable(d, 0.0, -r - 1.0e-3, :a); installation = duct)
end

@testitem "CableSystem with dual numbers" tags = [:ad] setup = [Fixtures] begin
    using ForwardDiff: ForwardDiff
    sys = Fixtures.mv_system(ForwardDiff.Dual(9.1e-3, 1.0))
    @test numtype(sys) <: ForwardDiff.Dual
    @test sys.earth isa EarthModel{numtype(sys)}
    @test ForwardDiff.derivative(r -> Fixtures.mv_system(r).cables[2].x, 9.1e-3) ≈ 1
end

@testitem "CableSystem with uncertain numbers" tags = [:uncertainty] setup = [Fixtures] begin
    using Measurements: measurement, Measurement
    import MonteCarloMeasurements as MCM

    @test numtype(Fixtures.mv_system(measurement(9.1e-3, 0.05e-3))) <: Measurement
    sys = Fixtures.mv_system(MCM.Particles(200, MCM.Normal(9.1e-3, 0.05e-3)))
    @test numtype(sys) <: MCM.Particles

    k_th = MCM.Particles(200, MCM.Uniform(0.7, 1.5))
    e = EarthModel(; rho = 100.0, k_th, T_ambient = 15.0)
    @test e isa EarthModel{<:MCM.Particles}
end
