@testitem "Material construction and promotion" tags = [:unit] begin
    m = Material("test"; rho = 1, alpha = 0.004)
    @test m isa Material{Float64}
    @test m.eps_r == 1 && m.mu_r == 1 && m.tan_delta == 0 && m.k_th == 0
    @test numtype(m) == Float64

    m32 = Material("test32"; rho = 1.0f0)
    @test m32 isa Material{Float32}
    @test Material("mixed"; rho = 1, alpha = 0.004f0) isa Material{Float32}

    big_m = Material{BigFloat}(COPPER)
    @test big_m isa Material{BigFloat}
    @test big_m.rho == BigFloat(COPPER.rho)
    @test convert(Material{Float64}, COPPER) === COPPER

    @test @inferred(Material("x", 1.0, 0.0, 1.0, 1.0, 0.0, 0.0)) isa Material{Float64}
    @test @inferred(Material("x"; rho = 1.0f0)) isa Material{Float32}
end

@testitem "Material equality and hashing" tags = [:unit] begin
    @test Material{BigFloat}(COPPER) == Material{BigFloat}(COPPER)
    @test isequal(Material{BigFloat}(COPPER), Material{BigFloat}(COPPER))
    @test hash(Material{BigFloat}(COPPER)) == hash(Material{BigFloat}(COPPER))
    @test Material("copper"; rho = 1.7241e-8, alpha = 3.93e-3) == COPPER
    @test COPPER != ALUMINIUM
    @test length(Set([COPPER, Material{Float64}(COPPER), ALUMINIUM])) == 2
end

@testitem "Material display" tags = [:unit] begin
    @test sprint(show, COPPER) == "Material(\"copper\")"
    txt = sprint(show, MIME"text/plain"(), COPPER)
    @test startswith(txt, "Material{Float64} \"copper\"")
    @test occursin("rho       = 1.7241e-8 Ω·m", txt)
    @test occursin("k_th      = 0.0 K·m/W", txt)
end

@testitem "Material with dual numbers" tags = [:unit] begin
    using ForwardDiff: ForwardDiff
    f(rho) = Material("d"; rho, alpha = 3.93e-3).rho * 2
    @test ForwardDiff.derivative(f, 1.0) == 2
    m = Material("d"; rho = ForwardDiff.Dual(1.0, 1.0), alpha = 3.93e-3)
    @test numtype(m) <: ForwardDiff.Dual
end

@testitem "Material validation" tags = [:unit] begin
    @test_throws ArgumentError Material("bad"; rho = 0.0)
    @test_throws ArgumentError Material("bad"; rho = 1.0, eps_r = 0.5)
    @test_throws ArgumentError Material("bad"; rho = 1.0, mu_r = 0.5)
    @test_throws ArgumentError Material("bad"; rho = 1.0, tan_delta = -1.0)
    @test_throws ArgumentError Material("bad"; rho = 1.0, k_th = -1.0)
    @test_throws ArgumentError Material("bad"; rho = Inf)
    @test_throws ArgumentError Material("bad"; rho = 1.0, alpha = NaN)
    @test_throws ArgumentError Material("bad"; rho = 1.0, eps_r = Inf)
end

@testitem "Standard material library" tags = [:unit] begin
    lib = (
        COPPER, ALUMINIUM, LEAD, STEEL, XLPE, PVC, EPR, PAPER_OIL, MASS_IMPREGNATED, SEMICON,
    )
    @test all(m -> m isa Material{Float64}, lib)
    @test allunique(m.name for m in lib)

    # Metals conduct many orders of magnitude better than insulation.
    @test all(m.rho < 1.0e-6 for m in (COPPER, ALUMINIUM, LEAD, STEEL))
    @test all(m.rho > 1.0e10 for m in (XLPE, PVC, EPR, PAPER_OIL, MASS_IMPREGNATED))
    @test STEEL.mu_r > 1
end

@testitem "UnsupportedError message" tags = [:unit] begin
    e = UnsupportedError("not here", "use that")
    msg = sprint(showerror, e)
    @test occursin("not here", msg) && occursin("use that", msg)
    @test sprint(showerror, UnsupportedError("not here")) == "UnsupportedError: not here"
end
