using Bridge, Distributions
using Test, LinearAlgebra

h = 1e-7    
n, m = 50, 10000
T1 = 1.
T2 = 2.
T = T2-T1
ss = range(T1, stop=T2, length=n)
tt = Bridge.tofs(ss, T1, T2)

u = 0.5
v = 0.3
a = .7
a2 = 0.4
P = LinPro(-0.8, 0.0, sqrt(a))
P2 = LinPro(-0.8, 0.0, sqrt(a2))

la = 1
cs = Bridge.CSpline(T1, T2, la*P.B*u, la*P.B*v)
Po = BridgeProp(P, tt, (u, v), a, cs)
Pt = Bridge.ptilde(Po)

cs2 = Bridge.CSpline(T1, T2, P2.B*u, P2.B*v)
Po2 = BridgeProp(P2, tt, (u, v), a2, cs)
Pt2 = Bridge.ptilde(Po2)



s = ss[div(n,2)]
t = tt[div(n,2)]
@test Bridge.V(t, T2, v, Pt) ≈ Bridge.Vs(s, T1, T2, v, Pt)
@test Bridge.dotV(t, T2, v, Pt) ≈ Bridge.dotVs(s, T1, T2, v, Pt)
@test abs((Bridge.V(t+h, T2, v, Pt) - Bridge.V(t, T2, v, Pt))/h - Bridge.dotV(t, T2, v, Pt)) < h

@test tt[1] == T1
@test tt[end] == T2
@test (Bridge.V(T1, T2, v, Pt) - u)/T ≈ Bridge.uofx(T1, Po.v[1], T1, T2, v, Pt) # 
@test [T1, u] ≈ [Bridge.txofsu(T1, Bridge.uofx(T1, Po.v[1], T1, T2, v, Pt), T1, T2, v, Pt)...]
@test norm(Bridge.soft(Bridge.tofs(1:0.1:2, 1, 2), 1,2 ) .- (1:0.1:2)) < sqrt(eps())

if la == 1
    @test norm(Bridge.b(T1, u, P) - Bridge.b(T1, u, Pt)) + norm(Bridge.b(T2, v, P) - Bridge.b(T2, v,Pt)) < sqrt(eps())
end

X = Bridge.bridge(EulerMaruyama(), sample(ss, Wiener{Float64}()), Po)
Y = Bridge.bridge(EulerMaruyama(), Bridge.innovations(EulerMaruyama(), X, Po), Po)
@test Y.tt ≈ X.tt
@test Y.yy ≈ X.yy

X = ubridge(sample(ss, Wiener{Float64}()), Po)
@test X.tt ≈ tt
Y = ubridge(Bridge.uinnovations(X, Po), Po)
@test Y.tt ≈ X.tt
@test Y.yy ≈ X.yy


X = Bridge.bridge(Bridge.Mdb(), sample(ss, Wiener{Float64}()), Po)
Y = Bridge.bridge(Bridge.Mdb(), innovations(Bridge.Mdb(), X, Po), Po)
@test Y.tt ≈ X.tt
@test Y.yy ≈ X.yy

p = pdf(transitionprob(T1, u, T2, P), v)
pt = exp(lptilde(Po))

C = []
Co = []
Cnames = []
push!(Cnames, "Euler") 
z = Float64[
    let
        X = bridge(EulerMaruyama(), sample(tt, Wiener{Float64}()), Po)
         Bridge.llikelihoodleft(X, Po)
    end
    for i in 1:m]
 
o = mean(exp.(z)*pt/p); push!(Co, o); push!(C, abs(o - 1)*sqrt(m)/std(exp.(z)*pt/p))

 
push!(Cnames, "Euler + Trapez") 
z = Float64[
    let
        X = bridge(EulerMaruyama(), sample(tt, Wiener{Float64}()), Po)
         Bridge.llikelihoodtrapez(X, Po)
    end
    for i in 1:m]
 
o = mean(exp.(z)*pt/p); push!(Co, o); push!(C, abs(o - 1)*sqrt(m)/std(exp.(z)*pt/p))

push!(Cnames, "MDGP+Left")
z = Float64[
    let
        X = bridge(Bridge.Mdb(), sample(tt, Wiener{Float64}()), Po)
        Bridge.llikelihoodleft(X, Po)
    end
    for i in 1:m]
 
o = mean(exp.(z)*pt/p); push!(Co, o); push!(C, abs(o - 1)*sqrt(m)/std(exp.(z)*pt/p))

push!(Cnames, "MDGP+Trapez")
z = Float64[
    let
        X = bridge(Bridge.Mdb(), sample(tt, Wiener{Float64}()), Po)
        Bridge.llikelihoodtrapez(X, Po)
    end
    for i in 1:m]
 
o = mean(exp.(z)*pt/p); push!(Co, o); push!(C, abs(o - 1)*sqrt(m)/std(exp.(z)*pt/p))


push!(Cnames, "TCSGP")
z = Float64[
    let
        X = ubridge(sample(ss, Wiener{Float64}()), Po)
        Bridge.llikelihoodleft(X, Po)
    end
    for i in 1:m]

o = mean(exp.(z)*pt/p); push!(Co, o); push!(C, abs(o - 1)*sqrt(m)/std(exp.(z)*pt/p))


push!(Cnames, "TCSGP + Trapez")
z = Float64[
    let
        X = ubridge(sample(ss, Wiener{Float64}()), Po)
        Bridge.llikelihoodtrapez(X, Po)
    end
    for i in 1:m]

o = mean(exp.(z)*pt/p); push!(Co, o); push!(C, abs(o - 1)*sqrt(m)/std(exp.(z)*pt/p))


push!(Cnames, "TCSGPLL")
z = Float64[
    let
        X = ubridge(sample(ss, Wiener{Float64}()), Po)
        ullikelihood(X, Po)
    end
    for i in 1:m]
o = mean(exp.(z)*pt/p); push!(Co, o); push!(C, abs(o - 1)*sqrt(m)/std(exp.(z)*pt/p))

push!(Cnames, "TCSGPLL + Trapez")
z = Float64[
    let
        X = ubridge(sample(ss, Wiener{Float64}()), Po)
        Bridge.ullikelihoodtrapez(X, Po)
    end
    for i in 1:m]
o = mean(exp.(z)*pt/p); push!(Co, o); push!(C, abs(o - 1)*sqrt(m)/std(exp.(z)*pt/p))

push!(Cnames, "TCSGP + Inno + Update")
z = Float64[
                  let
                      X = ubridge(sample(ss, Wiener{Float64}()), Po2)
                      Z = Bridge.uinnovations(X, Po2) 
                      Z2 = sample(Z.tt, Wiener{Float64}())
                      Z.yy[:] = sqrt(.8)*Z.yy + sqrt(0.2)*Z2.yy
                      Z.yy[end]
                      X = ubridge(Z, Po)
                      Bridge.llikelihoodleft(X, Po)
                  end
                  for i in 1:m]

o = mean(exp.(z)*pt/p); push!(Co, o); push!(C, abs(o - 1)*sqrt(m)/std(exp.(z)*pt/p))

push!(Cnames, "TCSGPLL + Inno Mix")
z = Float64[
           let
               W = sample(ss, Wiener{Float64}())
               X = ubridge(W, Po2)
               Z = Bridge.innovations(EulerMaruyama(), X, Po2) 
               X = bridge(EulerMaruyama(), Z, Po)
               Bridge.llikelihoodtrapez(X, Po)
           end
           for i in 1:m]
o = mean(exp.(z)*pt/p); push!(Co, o); push!(C, abs(o - 1)*sqrt(m)/std(exp.(z)*pt/p))

push!(Cnames, "MDGP + Trapez + Inno")
z = Float64[
    let
        X = bridge(Bridge.Mdb(), sample(tt, Wiener{Float64}()), Po2)
        W = innovations(EulerMaruyama(), X, Po2) 
        X = bridge(EulerMaruyama(), W, Po)
        Bridge.llikelihoodtrapez(X, Po)
    end
    for i in 1:m]
 
o = mean(exp.(z)*pt/p); push!(Co, o); push!(C, abs(o - 1)*sqrt(m)/std(exp.(z)*pt/p))

display([Cnames C Co])
println("\n  Method                   rel error  mean")
println("Remark: Change of measure is successfull if mean is close to 1")
