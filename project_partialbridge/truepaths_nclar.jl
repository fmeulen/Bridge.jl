tt = 0.:dt:T
# Generate Data

Random.seed!(2)
# generate one long path
T_long = 10.0
tt_long = 0.:dt:T_long
W_long = sample(tt_long, Wiener())
X_long = solve(Euler(), x0, W_long, P)
# write long forward to csv file
f = open(outdir*"longforward_nclar.csv","w")
head = "time, component, value \n"
write(f, head)
longpath = [Any[tt_long[j], d, X_long.yy[j][d]] for d in 1:3, j in 1:length(X_long) ][:]
writedlm(f, longpath, ',')
close(f)

# simulate forwards, on the shorter interval
Random.seed!(3)
W = sample(tt, Wiener())
X = solve(Euler(), x0, W, P)
XX = [X]
samples = 100
# draw more paths
for j in 2:samples
    W = sample(tt, Wiener())
    X = solve(Euler(), x0, W, P)
    push!(XX, X)
end

# write forwards to csv file
f = open(outdir*"forwards_nclar.csv","w")
head = "samplenr, time, component, value \n"
write(f, head)
iterates = [Any[i, tt[j], d, XX[i].yy[j][d]] for d in 1:3, j in 1:length(X), i in 1:samples ][:]
writedlm(f, iterates, ',')
close(f)

# simulate forwards, on the shorter interval
# Random.seed!(3)
# W = sample(tt, Wiener())
# X = solve(Euler(), x0, W, P)
# XX = []
# samples = 30
# s = 0
# # draw more paths
# while true
#     sample!(W, Wiener())
#     solve!(Euler(), X, x0, W, P)
#     if norm(L*X.yy[end] .- v) < 0.01
#         push!(XX, copy(X))
#         s += 1
#         s % 10 == 0 && println(".")
#         s >= samples && break
#     end
# end
#
# # write 'forward-bridges' to csv file
# f = open(outdir*"bridges_nclar-"*obs_scheme*".csv","w")
# head = "samplenr, time, component, value \n"
# write(f, head)
# iterates = [Any[i, tt[j], d, XX[i].yy[j][d]] for d in 1:3, j in 1:length(X), i in 1:samples ][:]
# writedlm(f, iterates, ',')
# close(f)
#
# tt = τ(T).(0.:dt:T)
