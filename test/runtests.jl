include(joinpath("..", "docs", "make.jl")) # this may change rng state
using Random
Random.seed!(12)

include("wiener.jl")
include("diffusion.jl")
include("euler.jl")
include("misc.jl")
include("VHK.jl")
include("guip.jl")
include("partialbridge.jl")
include("linpro.jl")
include("linprobridge.jl")
include("timechange.jl")
include("uniformscaling.jl")
include("gamma.jl") 
include("gaussian.jl")
include("bessel.jl")

include("with_srand.jl") # run last
