using BloqadeSchema
using Configurations
using Test



@testset "capabilities" begin
    include("capabilities.jl")
end

@testset "parse" begin
    include("parse.jl")
end

# TODO: add tests
@testset "transform" begin
    include("transform.jl")
end

# TODO: add tests 
@testset "validate" begin
    include("validate.jl")
end

# TODO: rework tests for execute.
@testset "execute" begin
    include("execute.jl")
end

@testset "types" begin
    include("types.jl")
end

# @testset "serialize" begin
#     include("serialize.jl")
# end
