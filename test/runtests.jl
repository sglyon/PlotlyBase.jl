module PlotlyBaseTest
using TestSetExtensions

using Base.Test

using PlotlyBase
const M = PlotlyBase

try
    @testset ExtendedTestSet "PlotlyJS Tests" begin
        @includetests ARGS
    end
catch
    exit(-1)
end

end
