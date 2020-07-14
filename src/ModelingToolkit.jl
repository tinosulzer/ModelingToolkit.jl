module ModelingToolkit

using DiffEqBase, Distributed
using StaticArrays, LinearAlgebra, SparseArrays, LabelledArrays
using Latexify, Unitful, ArrayInterface
using MacroTools
using UnPack: @unpack
using DiffEqJump
using DataStructures: OrderedDict, OrderedSet
using SpecialFunctions, NaNMath
using Base.Threads
import MacroTools: splitdef, combinedef, postwalk, striplines
import GeneralizedGenerated
using DocStringExtensions
using Base: RefValue

using RecursiveArrayTools

import SymbolicUtils
import SymbolicUtils: to_symbolic, FnType, @rule, Rewriters

import LightGraphs: SimpleDiGraph, add_edge!

import TreeViews

using Requires

"""
$(TYPEDEF)

Base type for a symbolic expression.
"""
abstract type Expression <: Number end


export Num
"""
$(TYPEDEF)

Wrap anything in a type that is a subtype of Number
"""
struct Num <: Number
    val
end

const show_numwrap = Ref(false)

Num(x::Num) = x # ideally this should never be called
(f::Num)(args...) = Num(f(args...))
value(x) = x
value(x::Num) = x.val
SymbolicUtils.@number_methods(Num,
                              Num(f(value(a))),
                              Num(f(value(a), value(b))))

SymbolicUtils.simplify(n::Num; kw...) = SymbolicUtils.simplify(value(n); kw...)

function Base.iszero(x::Num)
    _x = SymbolicUtils.to_mpoly(value(x))[1]
    return (_x isa Number || _x isa SymbolicUtils.MPoly) && iszero(_x)
end

import SymbolicUtils: <ₑ, Symbolic, Term, operation, arguments

Base.show(io::IO, n::Num) = show_numwrap[] ? print(io, :(Num($(value(n))))) : Base.show(io, value(n))

Base.promote_rule(::Type{<:Number}, ::Type{<:Num}) = Num
Base.promote_rule(::Type{<:Symbolic{<:Number}}, ::Type{<:Num}) = Num
Base.getproperty(t::Term, f::Symbol) = f === :op ? operation(t) : f === :args ? arguments(t) : getfield(t, f)
<ₑ(s::Num, x) = value(s) <ₑ value(x)
<ₑ(s, x::Num) = value(s) <ₑ value(x)
<ₑ(s::Num, x::Num) = value(s) <ₑ value(x)

Base.:(^)(n::Num, i::Integer) = Num(Term{symtype(n)}(^, [value(n),i]))

Base.convert(::Type{Num}, x::Symbolic{<:Number}) = Num(x)
Base.convert(::Type{Num}, x::Number) = Num(x)
Base.convert(::Type{Num}, x::Num) = x

Base.convert(::Type{<:Array{Num}}, x::AbstractArray) = map(Num, x)
Base.convert(::Type{<:Array{Num}}, x::AbstractArray{Num}) = x

#=
# TODO: use register?
Base.isless(n::Num, x::Number) = value(n) < value(x)
Base.isless(n::Num, x::Num) = value(n) < value(x)
Base.isless(n::Number, x::Num) = value(n) < value(x)
=#

LinearAlgebra.lu(x::Array{Num}) = lu(x, Val{false}())

"""
$(TYPEDEF)

TODO
"""
abstract type AbstractSystem end
abstract type AbstractODESystem <: AbstractSystem end

Base.promote_rule(::Type{<:Number},::Type{<:Expression}) = Expression
Base.zero(::Type{<:Expression}) = Constant(0)
Base.zero(::Expression) = Constant(0)
Base.one(::Type{<:Expression}) = Constant(1)
Base.one(::Expression) = Constant(1)
Base.oneunit(::Expression) = Constant(1)
Base.oneunit(::Type{<:Expression}) = Constant(1)

"""
$(TYPEDSIGNATURES)

Get the set of independent variables for the given system.
"""
function independent_variables end

"""
$(TYPEDSIGNATURES)

Get the set of states for the given system.
"""
function states end

"""
$(TYPEDSIGNATURES)

Get the set of parameters variables for the given system.
"""
function parameters end

include("variables.jl")
include("context_dsl.jl")
include("operations.jl")
include("differentials.jl")

function Base.convert(::Type{Variable},x::Operation)
    if x.op isa Variable
        x.op
    elseif x.op isa Differential
        var = x.args[1].op
        rename(var,Symbol(var.name,:ˍ,x.op.x))
    else
        throw(error("This Operation is not a Variable"))
    end
end

include("equations.jl")
include("function_registration.jl")
include("utils.jl")
include("linearity.jl")
include("direct.jl")
include("domains.jl")

include("systems/abstractsystem.jl")

include("systems/diffeqs/odesystem.jl")
include("systems/diffeqs/sdesystem.jl")
include("systems/diffeqs/abstractodesystem.jl")
include("systems/diffeqs/first_order_transform.jl")
include("systems/diffeqs/modelingtoolkitize.jl")
include("systems/diffeqs/validation.jl")

include("systems/jumps/jumpsystem.jl")

include("systems/nonlinear/nonlinearsystem.jl")

include("systems/optimization/optimizationsystem.jl")

include("systems/pde/pdesystem.jl")

include("systems/reaction/reactionsystem.jl")
include("systems/dependency_graphs.jl")

include("latexify_recipes.jl")
include("build_function.jl")

export ODESystem, ODEFunction, ODEFunctionExpr, ODEProblemExpr
export SDESystem, SDEFunction, SDEFunctionExpr, SDESystemExpr
export JumpSystem
export ODEProblem, SDEProblem
export NonlinearProblem, NonlinearProblemExpr
export OptimizationProblem, OptimizationProblemExpr
export SteadyStateProblem, SteadyStateProblemExpr
export JumpProblem, DiscreteProblem
export NonlinearSystem, OptimizationSystem
export ode_order_lowering
export PDESystem
export Reaction, ReactionSystem, ismassaction, oderatelaw, jumpratelaw
export Differential, expand_derivatives, @derivatives
export IntervalDomain, ProductDomain, ⊗, CircleDomain
export Equation, ConstrainedEquation
export Operation, Expression, Variable
export independent_variable, states, parameters, equations

export calculate_jacobian, generate_jacobian, generate_function
export calculate_tgrad, generate_tgrad
export calculate_gradient, generate_gradient
export calculate_factorized_W, generate_factorized_W
export calculate_hessian, generate_hessian
export calculate_massmatrix, generate_diffusion_function
export stochastic_integral_transform

export BipartiteGraph, equation_dependencies, variable_dependencies
export eqeq_dependencies, varvar_dependencies
export asgraph, asdigraph

export simplified_expr, rename, get_variables
export simplify, substitute
export build_function
export @register
export modelingtoolkitize
export @variables, @parameters

const HAS_DAGGER = Ref{Bool}(false)
function __init__()
    @require Dagger="d58978e5-989f-55fb-8d15-ea34adc7bf54" include("dagger.jl")
end

end # module
