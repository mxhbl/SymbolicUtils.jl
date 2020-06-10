using AbstractAlgebra
using SymbolicUtils
using SymbolicUtils: Term, operation, arguments, symtype, Sym

"""
    labels(dict, t)

Find all terms that are not + and * and replace them
with a symbol, store the symbol => term mapping in `dict`.
"""
function labels end

# Turn a Term into a multivariate polynomial
labels(dicts, t) = t
function labels(dicts, t::Sym)
    sym2term, term2sym = dicts
    if !haskey(term2sym, t)
        sym2term[t] = t
        term2sym[t] = t
    end
    return t
end

function labels(dicts, t::Term)
    tt = arguments(t)
    if operation(t) == (*) || operation(t) == (+)
        return Term{symtype(t)}(operation(t), map(x->labels(dicts, x), tt))
    else
        sym2term, term2sym = dicts
        if haskey(term2sym, t)
            return term2sym[t]
        end

        sym = Sym{symtype(t)}(gensym(nameof(operation(t))))
        sym2term[sym] = Term{symtype(t)}(operation(t), map(x->labels(dicts, x), tt))
        x = term2sym[t] = sym

        return x
    end
end

import SymbolicUtils: istree, operation, arguments, Symbolic, isliteral
import AbstractAlgebra.Generic: MPoly
using AbstractAlgebra: ismonomial


struct PolynomialTerm{T}
    sym2term::Dict
    term2sym::Dict
    mpoly::MPoly
end

issym(x::MPoly) = ismonomial(x) && sum(x.exps) == 1

ismpoly(x) = x isa MPoly || x isa Integer

function to_mpoly(t)
    sym2term, term2sym = Dict(), Dict()
    ls = labels((sym2term, term2sym), t)

    ks = collect(keys(sym2term))
    R, vars = PolynomialRing(ZZ, @show String.(nameof.(ks)))

    t_poly_1 = substitute(t, term2sym, fold=false)
    t_poly_2 = substitute(t_poly_1, Dict(ks .=> vars), fold=false)
    rs = RuleSet([@acrule(~x::ismpoly + ~y::ismpoly => ~x + ~y)
                  @rule(+(~x) => ~x)
                  @acrule(~x::ismpoly * ~y::ismpoly => ~x * ~y)
                  @rule(*(~x) => ~x)
                  @rule((~x::ismpoly)^(~a::isliteral(Integer)) => (~x)^(~a))])
    simplify(t_poly_2, rules=rs)
end

#=

julia> x=a * (b + -1 * c) + -1 * (b * a + -1 * c * a)
(a * (b + (-1 * c))) + (-1 * ((a * b) + (-1 * a * c)))

julia> to_mpoly(x)
0
=#
