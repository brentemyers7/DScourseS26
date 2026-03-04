using Random, LinearAlgebra
function scriptwrapper()
    X = [ones(15,1) rand(15,3)]
    y = randn(15,1)
    β = X\y # compute OLS
    return β
end
βhat = scriptwrapper()