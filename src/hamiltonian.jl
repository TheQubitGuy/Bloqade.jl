using BitBasis
using ExponentialUtilities
using SparseArrays
export to_matrix, RydbergHamiltonian

"""
    subspace(n::Int, mis::Vector)

Create a subspace from given maximal independent set `mis`.
"""
function subspace(n::Int, mis::Vector)
    it = map(mis) do each
        fixed_points = setdiff(1:n, each)
        itercontrol(n, fixed_points, zero(fixed_points))
    end
    return sort(unique(Iterators.flatten(it)))
end

getscalarmaybe(x::Vector, k) = x[k]
getscalarmaybe(x::Number, k) = x

"""
    sigma_x_term!(dst::AbstractMatrix{T}, n::Int, lhs, i, subspace_v, Ω, ϕ) where {T}

Sigma X term of the Rydberg Hamiltonian in MIS subspace:

```math
\sum_{i=0}^n \Omega_i (e^{iϕ_i})|0⟩⟨1| + e^{-iϕ_i}|1⟩⟨0|)
```
"""
function sigma_x_term!(dst::AbstractMatrix{T}, n::Int, lhs, i, subspace_v, Ω, ϕ) where {T}
    sigma_x = zero(T)
    for k in 1:n
        each_k = readbit(lhs, k)
        rhs = flip(lhs, 1 << (k - 1))
        # TODO: optimize this part by reusing node id
        # generated by creating subspace
        if rhs in subspace_v
            j = findfirst(isequal(rhs), subspace_v)
            if each_k == 0
                dst[i, j] = getscalarmaybe(Ω, k) * exp(im * getscalarmaybe(ϕ, k))
            else
                dst[i, j] = getscalarmaybe(Ω, k) * exp(-im * getscalarmaybe(ϕ, k))
            end
        end
    end
    return dst
end

"""
    sigma_z_term!(dst::AbstractMatrix{T}, n::Int, lhs, i, Δ) where {T <: Number}

Sigma Z term of the Rydberg Hamiltonian in MIS subspace.

```math
\sum_{i=1}^n Δ_i σ_i^z
```
"""
function sigma_z_term!(dst::AbstractMatrix{T}, n::Int, lhs, i, Δ) where {T <: Number}
    sigma_z = zero(T)
    for k in 1:n
        if readbit(lhs, k) == 1
            sigma_z -= getscalarmaybe(Δ, k)
        else
            sigma_z += getscalarmaybe(Δ, k)
        end
    end
    dst[i, i] = sigma_z
    return dst
end

"""
    to_matrix!(dst::AbstractMatrix{T}, n::Int, subspace_v, Ω, ϕ[, Δ]) where T

Create a Rydberg Hamiltonian matrix from given parameters inplace. The matrix is preallocated as `dst`.
"""
function to_matrix!(dst::AbstractMatrix, n::Int, subspace_v, Ω, ϕ, Δ)
    for (i, lhs) in enumerate(subspace_v)
        sigma_z_term!(dst, n, lhs, i, Δ)
        sigma_x_term!(dst, n, lhs, i, subspace_v, Ω, ϕ)
    end
    return dst
end

# TODO: RL: polish this part to make it more compact
function to_matrix!(dst::AbstractMatrix, n::Int, subspace_v, Ω, ϕ)
    for (i, lhs) in enumerate(subspace_v)
        sigma_x_term!(dst, n, lhs, i, subspace_v, Ω, ϕ)
    end
    return dst
end

function to_matrix(graph, Ω, ϕ, Δ)
    cg = complement(graph)
    mis = maximal_cliques(cg)
    n = nv(graph)
    subspace_v = subspace(n, mis)
    m = length(subspace_v)
    H = spzeros(ComplexF64, m, m)
    to_matrix!(H, n, subspace_v, Ω, ϕ, Δ)
    return Hermitian(H)
end

struct RydbergHamiltonian
    C::Float64
    Ω::Vector{Float64}
    ϕ::Vector{Float64}
    Δ::Vector{Float64}
    atoms::AtomPosition
end

n_atoms(h::RydbergHamiltonian) = length(h.atoms)

function to_matrix(h::RydbergHamiltonian)
    g = unit_disk_graph(h.atoms)
    return to_matrix(g, h.Ω, h.ϕ, h.Δ)
end

function timestep!(st::Vector, h::RydbergHamiltonian, t::Float64, dt::Float64)
    H = to_matrix(h)
    return expv(-im * t, H, st)
end
