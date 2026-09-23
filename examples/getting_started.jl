# Getting started with CableLineModels.jl
#
#     julia examples/getting_started.jl

using Pkg: Pkg
Pkg.activate(@__DIR__)

using CableLineModels: Conductor, RoundStranded, CableCore, SemiconLayer, InsulationLayer,
    WireScreen, Jacket, CableDesign, CableSystem, trefoil, LoopMethod, compute_ZY,
    ALUMINIUM, COPPER, XLPE, PVC

# A typical cable: all lengths in metres, so the area is in m².
design = CableDesign(COPPER, 240.0e-6; U0 = 12.0e3)
display(design)

# Defaults: 1 km route, 50 Hz, soil of 100 Ω·m.
system = CableSystem(trefoil(design))
display(system)
zy = compute_ZY(system, LoopMethod(), 0.0; T_conductor = 90, T_screen = 70)
display(zy)

# A specific cable, layer by layer from the inside out.
conductor = Conductor(RoundStranded(37), ALUMINIUM; r_out = 9.1e-3, area_nominal = 240.0e-6)
core = CableCore(
    conductor, [
        SemiconLayer(9.1e-3, 9.6e-3),
        InsulationLayer(9.6e-3, 15.1e-3, XLPE),
        SemiconLayer(15.1e-3, 15.6e-3),
        WireScreen(16.2e-3, 40, 0.45e-3, 0.2, COPPER),
        Jacket(16.65e-3, 19.15e-3, PVC),
    ],
)

custom = CableDesign("MV 1x240 Al 12/20 kV", core; U0 = 12.0e3)
display(custom)

display(compute_ZY(CableSystem(trefoil(custom)), LoopMethod(), 0.0; T_conductor = 90, T_screen = 70))
