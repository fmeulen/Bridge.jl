using Bridge, StaticArrays, Distributions, PyPlot
using Base.Test
import Base.Math.gamma # just to use the name
#import Bridge: b, σ, a, transitionprob
using Bridge: runmean

const percentile = 3.0
const SV = SVector{2,Float64}
const SM = SMatrix{2,2,Float64,4}

kernel(x, a=0.001) = exp(Bridge.logpdfnormal(x, a*I))

TEST = false
CLASSIC = false

@inline _traceB(t, K, P) = trace(Bridge.B(t, P))

traceB(tt, u::T, P) where {T} = solve(Bridge.R3(), _traceB, tt, u, P)



using Bridge.outer

# Define a diffusion process
if ! @_isdefined(Target)
struct Target  <: ContinuousTimeProcess{SV}
    c::Float64
    κ::Float64
end
end

if ! @_isdefined(Linear)
struct Linear  <: ContinuousTimeProcess{SV}
    T::Float64
    v::SV
    b11::Float64
    b21::Float64
    b12::Float64
    b22::Float64
end
end


g(t, x) = sin(x)
gamma(t, x) = 1.2 - sech(x)/2

# define drift and sigma of Target

Bridge.b(t, x, P::Target) = SV(P.κ*x[2] - P.c*x[1],  -P.c*x[2] + g(t, x[2]))::SV
Bridge.σ(t, x, P::Target) = SM(0.5, 0.0, 0.0, gamma(t, x[2]))
Bridge.a(t, x, P::Target) = SM(0.25, 0, 0, outer(gamma(t, x[2])))
Bridge.constdiff(::Target) = false


# define drift and sigma of Linear approximation
 
Bridge.b(t, x, P::Linear) = SV(P.b11*x[1] + P.b12*x[2], P.b21*x[1] + P.b22*x[2] + g(P.T, P.v[2]))
Bridge.B(t, P::Linear) = SM(P.b11, P.b21, P.b12, P.b22)

Bridge.β(t, P::Linear) = SV(0, g(P.T, P.v[2]))

Bridge.σ(t, x, P::Linear) = SM(0.5, 0, 0, gamma(P.T, P.v[2]))
Bridge.a(t, x, P::Linear) = SM(0.25, 0, 0, outer(gamma(P.T, P.v[2])))
Bridge.a(t, P::Linear) = SM(0.25, 0, 0, outer(gamma(P.T, P.v[2])))
Bridge.constdiff(::Linear) = false

Q = Normal()

c = 0.0
κ = 3.0

# times

t = 0.7
T = 1.5
S = (t + T)/2

# grid

n = 401
dt = (T-t)/(n-1)
tt = t:dt:T
tt1 = t:dt:S
tt2 = S:dt:T

m = 200_000

Ti = n
Si = n÷2

# observations

Σ = 1.0 # observation noise
L = @SMatrix [1.0 0.0]

xt = @SVector [0.1, 0.0]
vS = @SVector [-0.5]
xT = @SVector [0.3, -0.6]

# processes

P = Target(c, κ)
Pt = Linear(T, xT, -c-0.1, -0.1, κ-0.1, -c/2)

# parameters

B = Bridge.B(0, Pt)
β = Bridge.β(0, Pt)
a = Bridge.a(0, Pt)
σ = sqrtm(Bridge.a(0, Pt))



W = sample(tt, Wiener{SV}())
W1 = sample(tt1, Wiener{SV}())
W2 = sample(tt2, Wiener{SV}())


# Target and log probability density (forward simulation)

YT = SV[]
YS = Float64[]
p = Float64[]
X = SamplePath(tt, zeros(SV, length(tt)))
Xs = SamplePath(tt, zeros(SV, length(tt)))
best = Inf
for i in 1:m
    W = sample!(W, Wiener{SV}())
    Bridge.solve!(Euler(), X, xt, W, P)
    push!(YT, X.yy[end])
    push!(YS, X.yy[end÷2][2]) # depends on L
    
    eta = rand(Q)
    nrm = norm(xT - X.yy[Ti]) + norm(vS - eta - L*X.yy[Si])
    l = kernel(xT - X.yy[Ti])*kernel(vS - L*X.yy[Si], 1.0)
    push!(p, l)
    if nrm < best
        best = nrm
        Xs.yy .= X.yy
    end
end

lphat = log(mean(p))

# Proposal log probability density (forward simulation)

pt = Float64[]
Xt = SamplePath(tt, zeros(SV, length(tt)))
l = 0.0
for i in 1:m
    W = sample!(W, Wiener{SV}())
    Bridge.solve!(Euler(), Xt, xt, W, Pt)
    eta = rand(Q)
    l =  kernel(xT - Xt.yy[Ti])*kernel(vS - L*Xt.yy[Si], 1.0) # likelihood
    push!(pt, l)
end
lpthat = log(mean(pt))

@show lpthat

# Plot best "bridge"

clf()
subplot(121)
plot(Xs.tt, Xs.yy, label="X*")
plot.(t, xt, "ro")
plot(S, vS, "ro")
plot.(T, xT, "ro")

legend()


# Proposal

Z = Float64[]
Xo1 = SamplePath(tt1, zeros(SV, length(tt)))
Xo2 = SamplePath(tt2, zeros(SV, length(tt)))

@time for i in 1:m
    GP2 = GuidedBridge(tt2, P, Pt, xT)
    H♢, V = Bridge.gpupdate(GP2, L, Σ, vS)
    GP1 = GuidedBridge(tt1, P, Pt, V, H♢)
    
    sample!(W1, Wiener{SV}())
    sample!(W2, Wiener{SV}())
    y = Bridge.bridge!(Xo1, xt, W1, GP1)
    Bridge.bridge!(Xo2, y, W2, GP2)

    
    ll = llikelihood(LeftRule(), Xo1, GP1) + llikelihood(LeftRule(), Xo2, GP2)
    push!(Z, exp(ll))
end

@show log(mean(exp.(pthat))), lphat

subplot(122)
step = 10
plot(mean(pt)*runmean(Z)[1:step:end], label="Phi*pt")
plot(runmean(p)[1:step:end], label="p")
plot(runmean(pt)[1:step:end], label="pt")
legend()
axis([1, div(m,step), 0, 2*exp(lpt)])


error("done")




figure()
subplot(411)
plot(Xs.tt, Xs.yy, label="X*")
legend()


subplot(413)
plot(Xo.tt, Xo.yy, label="Xo")
legend()

subplot(414)
step = 10
plot(runmean(exp.(Z))[1:step:end], label="Xo")
plot(runmean(kernel.(Yv))[1:step:end], label="X")
plot(runmean(kernel.(Ytv))[1:step:end], label="Xt")
legend()
axis([1, div(m,step), 0, 2*exp(lpt)])



ex = Dict(
"u" => u,    
"v" => v,    
"Xo" => Xo,
"Xs" => Xs,
"Xts" => Xts,
"Yt" => Yt,
"Y" => Y,
"Z" => Z,
"lpt" => lpt
)