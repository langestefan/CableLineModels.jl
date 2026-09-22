@testitem "Aqua quality assurance" tags = [:quality] begin
    using Aqua: Aqua
    Aqua.test_all(CableLineModels)
end

@testitem "JET static analysis" tags = [:quality] begin
    using JET: JET
    JET.test_package(CableLineModels; target_modules = (CableLineModels,))
end
