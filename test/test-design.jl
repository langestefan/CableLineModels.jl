@testitem "Conductor shapes" tags = [:unit] begin
    @test RoundStranded(37).n_wires == 37
    @test Milliken(6).n_segments == 6
    @test_throws ArgumentError RoundStranded(0)
    @test_throws ArgumentError Milliken(0)
end

@testitem "Conductor construction and validation" tags = [:unit] begin
    c = Conductor(RoundSolid(), COPPER; r_out = 5, area_nominal = 78)
    @test c isa Conductor{Float64}
    @test inner_radius(c) == 0 && outer_radius(c) == 5
    @test c.R_dc20 === nothing && c.material === COPPER

    c32 = Conductor(RoundSolid(), COPPER; r_out = 5.0f0, area_nominal = 78.0f0)
    @test c32 isa Conductor{Float32} && c32.material === COPPER

    hollow = Conductor(Milliken(6), COPPER; r_in = 6.0e-3, r_out = 20.0e-3, area_nominal = 1.0e-3, R_dc20 = 1.8e-5)
    @test hollow.R_dc20 == 1.8e-5

    @test_throws ArgumentError Conductor(RoundSolid(), COPPER; r_out = 0.0, area_nominal = 1.0)
    @test_throws ArgumentError Conductor(RoundSolid(), COPPER; r_in = 2.0, r_out = 1.0, area_nominal = 1.0)
    @test_throws ArgumentError Conductor(RoundSolid(), COPPER; r_in = -1.0, r_out = 1.0, area_nominal = 1.0)
    @test_throws ArgumentError Conductor(RoundSolid(), COPPER; r_out = Inf, area_nominal = 1.0)
    @test_throws ArgumentError Conductor(RoundSolid(), COPPER; r_out = 1.0, area_nominal = 0.0)
    @test_throws ArgumentError Conductor(RoundSolid(), COPPER; r_out = 1.0, area_nominal = 1.0, R_dc20 = 0.0)
    @test_throws ArgumentError Conductor(RoundSolid(), COPPER; r_out = 1.0, area_nominal = 1.0, R_dc20 = NaN)
end

@testitem "Layer geometry" tags = [:unit] begin
    g = Annulus(1, 2)
    @test g isa Annulus{Float64} && inner_radius(g) == 1 && outer_radius(g) == 2
    w = WireGeometry(10.0e-3, 40, 0.5e-3, 0.2)
    @test w isa WireGeometry{Float64} && inner_radius(w) ≈ 9.5e-3

    l = InsulationLayer(Annulus(1.0f0, 2.0f0), XLPE)
    @test geometry(l) isa Annulus{Float32}
    @test geometry(l) == Annulus(1.0, 2.0)
    @test geometry(Armour(w, STEEL)) === w
    @test Armour(w, STEEL) != WireScreen(w, STEEL)
    @test Annulus(big(1), 2) == g && hash(Annulus(big(1), 2)) == hash(g)

    @test_throws "Annulus: need 0 < r_in < r_out" Annulus(2.0, 1.0)
    @test_throws "Jacket: need 0 < r_in < r_out" Jacket(2.0, 1.0, PVC)
    @test_throws "WireGeometry: n_wires" WireGeometry(1.0, 0, 0.1, 1.0)
    @test_throws "Armour: n_wires" Armour(1.0, 0, 0.1, 1.0, STEEL)
end

@testitem "Tubular layers" tags = [:unit] begin
    for L in (InsulationLayer, TubularScreen, Jacket)
        l = L(1, 2, XLPE)
        @test l isa L && l isa Layer
        @test (l isa TubularLayer) != (l isa WireLayer)
        @test inner_radius(l) == 1 && outer_radius(l) == 2
        @test_throws ArgumentError L(2.0, 1.0, XLPE)
        @test_throws ArgumentError L(1.0, 1.0, XLPE)
        @test_throws ArgumentError L(0.0, 1.0, XLPE)
        @test_throws ArgumentError L(1.0, NaN, XLPE)
    end
    @test SemiconLayer(1.0, 2.0).material == SEMICON
    @test SemiconLayer(Annulus(1.0, 2.0)).material == SEMICON
    @test InsulationLayer(1.0, 2.0, XLPE) == InsulationLayer(1.0f0, 2.0f0, XLPE)
    @test InsulationLayer(1.0, 2.0, XLPE) != Jacket(1.0, 2.0, XLPE)
end

@testitem "Wire layers" tags = [:unit] begin
    for L in (WireScreen, Armour)
        l = L(10.0e-3, 40, 0.5e-3, 0.2, COPPER)
        @test l isa L && l isa Layer
        @test (l isa TubularLayer) != (l isa WireLayer)
        @test inner_radius(l) ≈ 9.5e-3 && outer_radius(l) ≈ 10.5e-3
        @test_throws ArgumentError L(10.0e-3, 0, 0.5e-3, 0.2, COPPER)
        @test_throws ArgumentError L(10.0e-3, 40, 0.0, 0.2, COPPER)
        @test_throws ArgumentError L(10.0e-3, 1, 10.0e-3, 0.2, COPPER)
        @test_throws ArgumentError L(10.0e-3, 40, 0.5e-3, 0.0, COPPER)
        @test_throws ArgumentError L(10.0e-3, 40, 0.5e-3, Inf, COPPER)
    end
    @test WireScreen(1.0, 5, 0.5, 1.0, COPPER) isa WireScreen
    @test_throws ArgumentError WireScreen(1.0, 7, 0.5, 1.0, COPPER)
end

@testitem "CableCore stacking" tags = [:unit] begin
    c = Conductor(RoundSolid(), COPPER; r_out = 5.0e-3, area_nominal = 78.0e-6)
    ins = InsulationLayer(5.0e-3, 8.0e-3, XLPE)
    screen = TubularScreen(8.5e-3, 9.0e-3, LEAD)
    jacket = Jacket(9.0e-3, 11.0e-3, PVC)

    core = CableCore(c, [ins, screen, jacket])
    @test outer_radius(core) == 11.0e-3
    @test metallic_layers(core) == [screen]
    @test outer_radius(CableCore(c)) == 5.0e-3
    @test CableCore(c, [ins, screen, jacket]) == core

    mixed = CableCore(Conductor(RoundSolid(), COPPER; r_out = 5.0f-3, area_nominal = 78.0f-6), [ins])
    @test mixed.conductor.r_out isa Float32 && geometry(mixed.layers[1]) isa Annulus{Float64}

    @test_throws ArgumentError CableCore(c, [InsulationLayer(4.0e-3, 8.0e-3, XLPE)])
    @test_throws "layer 2 (Jacket)" CableCore(c, [ins, Jacket(7.0e-3, 9.0e-3, PVC)])
    @test_throws "layer 2 (WireScreen)" CableCore(c, [ins, WireScreen(8.2e-3, 20, 0.5e-3, 0.1, COPPER)])
end

@testitem "CableDesign single-core" tags = [:unit] setup = [Fixtures] begin
    core = Fixtures.mv_core()
    d = Fixtures.mv_design()
    @test d.layout == SingleCore()
    @test d.system_type == :ac && d.U0 == 12.0e3
    @test outer_radius(d) == outer_radius(core)
    @test d == Fixtures.mv_design() && hash(d) == hash(Fixtures.mv_design())
    @test d != Fixtures.mv_design(9.2e-3)

    jacketed = CableDesign("x", core; U0 = 12.0e3, common_layers = [Jacket(outer_radius(core), 0.03, PVC)])
    @test outer_radius(jacketed) == 0.03

    @test_throws ArgumentError CableDesign("x", core; U0 = 0.0)
    @test_throws ArgumentError CableDesign("x", core; U0 = Inf)
    @test_throws ArgumentError CableDesign("x", core; U0 = 1.0, system_type = :hvdc)
    @test_throws ArgumentError CableDesign("x", [core, core]; U0 = 1.0)
    @test_throws "layer 1 (Jacket)" CableDesign(
        "x", core; U0 = 1.0, common_layers = [Jacket(0.01, 0.03, PVC)],
    )
end

@testitem "CableDesign from material and area" tags = [:unit] begin
    d = CableDesign(ALUMINIUM, 240.0e-6; U0 = 12.0e3)
    @test d.name == "1x240 mm² aluminium, U0 = 12.0 kV"
    @test d.U0 == 12.0e3 && d.layout == SingleCore()
    core = only(d.cores)
    @test core.conductor.material === ALUMINIUM && core.conductor.area_nominal == 240.0e-6
    @test outer_radius(core.conductor) ≈ 9.11e-3 rtol = 1.0e-3
    ins = core.layers[2]
    @test ins isa InsulationLayer && outer_radius(ins) - inner_radius(ins) ≈ 5.5e-3
    screen = only(metallic_layers(core))
    @test screen isa WireScreen && screen.material === COPPER
    @test screen.geom.n_wires * pi * screen.geom.r_wire^2 >= 16.0e-6
    @test core.layers[end] isa Jacket

    @test CableDesign(COPPER, 25.0e-6; U0 = 3.6e3) isa CableDesign
    @test CableDesign(COPPER, 1000.0e-6; U0 = 18.0e3) isa CableDesign
    thin = CableDesign(COPPER, 95.0e-6; U0 = 12.0e3, t_insulation = 3.0e-3)
    @test outer_radius(thin) < outer_radius(CableDesign(COPPER, 95.0e-6; U0 = 12.0e3))
    @test_throws "pass t_insulation" CableDesign(COPPER, 630.0e-6; U0 = 64.0e3)
    @test CableDesign(COPPER, 630.0e-6; U0 = 64.0e3, t_insulation = 16.0e-3) isa CableDesign
    @test_throws "area" CableDesign(COPPER, 0.0; U0 = 12.0e3)
end

@testitem "CableDesign four-core LV" tags = [:unit] setup = [Fixtures] begin
    d = Fixtures.lv_design()
    @test d.layout isa FourCoreLV{Float64}
    @test length(d.cores) == 4
    @test outer_radius(d) == 20.2e-3

    core = d.cores[1]
    ro = outer_radius(core)
    @test CableDesign("x", fill(core, 4), FourCoreLV(ro * sqrt(2)); U0 = 600.0) isa CableDesign
    @test_throws "cores 1 and 2 overlap" CableDesign("x", fill(core, 4), FourCoreLV(ro); U0 = 600.0)
    @test_throws ArgumentError CableDesign("x", fill(core, 3), FourCoreLV(0.02); U0 = 600.0)
    @test_throws ArgumentError FourCoreLV(0.0)
    @test_throws "layer 1 (Jacket)" CableDesign(
        "x", fill(core, 4), FourCoreLV(10.5e-3); U0 = 600.0, common_layers = [Jacket(17.0e-3, 20.0e-3, PVC)],
    )
    @test FourCoreLV(1) isa FourCoreLV{Float64} && FourCoreLV(1).lay_length === nothing
    @test FourCoreLV(1.0f0; lay_length = 1).lay_length === 1.0f0
    @test_throws "lay_length must be positive" FourCoreLV(1.0; lay_length = 0.0)
end

@testitem "Design display" tags = [:unit] setup = [Fixtures] begin
    d = CableDesign(COPPER, 240.0e-6; U0 = 12.0e3)
    @test sprint(show, d) == "CableDesign(\"1x240 mm² copper, U0 = 12.0 kV\")"
    txt = repr("text/plain", d)
    @test startswith(txt, "CableDesign \"1x240 mm² copper, U0 = 12.0 kV\"\n  AC, U0 = 12.0 kV, SingleCore()")
    @test occursin("\n  core:\n    Conductor       copper", txt)
    @test occursin("mm, 32 wires", txt)
    @test startswith(repr("text/plain", only(d.cores)), "CableCore, radii inside-out:\n  Conductor")

    lv = repr("text/plain", Fixtures.lv_design())
    @test occursin("each of 4 cores:", lv) && occursin("common layers:\n    Jacket          PVC               18.2 – 20.2 mm", lv)
    mixed = Fixtures.lv_design()
    mixed = CableDesign("x", [mixed.cores[1:3]; CableCore(mixed.cores[1].conductor)], mixed.layout; U0 = 600.0, common_layers = mixed.common_layers)
    @test occursin("core 4:", repr("text/plain", mixed))
end

@testitem "Design types with dual numbers" tags = [:ad] setup = [Fixtures] begin
    using ForwardDiff: ForwardDiff
    @test ForwardDiff.derivative(r -> outer_radius(Fixtures.mv_design(r)), 9.1e-3) ≈ 1
    d = Fixtures.mv_design(ForwardDiff.Dual(9.1e-3, 1.0))
    @test d.cores[1].conductor.r_out isa ForwardDiff.Dual
    @test d.cores[1].conductor.material === ALUMINIUM
end

@testitem "Design types with uncertain numbers" tags = [:uncertainty] setup = [Fixtures] begin
    using Measurements: Measurements, measurement, Measurement
    import MonteCarloMeasurements as MCM

    d = Fixtures.mv_design(measurement(9.1e-3, 0.05e-3))
    @test outer_radius(d) isa Measurement
    @test Measurements.uncertainty(outer_radius(d)) ≈ 0.05e-3

    r_c = MCM.Particles(200, MCM.Normal(9.1e-3, 0.05e-3))
    d = Fixtures.mv_design(r_c)
    @test outer_radius(d) isa MCM.Particles
    @test MCM.pmean(outer_radius(d) - r_c) ≈ outer_radius(Fixtures.mv_design()) - 9.1e-3
end
