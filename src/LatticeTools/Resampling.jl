module Resampling
using ..LatticeCore
using Interpolations: Flat, Periodic, CubicSplineInterpolation
using FFTW: fftshift, ifftshift

export downsample, coarsen, upsample

cubic_spline_interpolation = CubicSplineInterpolation
#region ------------------downsample lattices ----------------------------

"""
    downsample(r::AbstractRange, n::Int)

    Downsample a range `r` by merging every `n` points into one, centered at the mean of the original points.

    # Arguments
    - `r::AbstractRange`: The original range to be downsampled.
    - `n::Int`: The number of points to be merged into one.

    # Returns
    - `AbstractRange`: A new downsampled range.

    # Errors
    Throws `DomainError` if `n` does not evenly divide the length of `r`.
    """
function downsample(r::AbstractRange, n::Int)
    # Downsamples a range r by merging n points into one, centered at the mean of the original points.
    # n must divide the length of r. 
    if length(r) % n != 0
        throw(DomainError((n, length(r)), "downsample: Downsample factor n does not divide the length of the range r."))
    end
    return (0:length(r)÷n-1) .* (step(r) * n) .+ (r[n] + r[1]) / 2
end

"""
    downsample(L::Lattice{N}, n::Int) where N

    Downsample a lattice `L` by merging every `n^N` points into one, centered at the mean of the original points.

    # Arguments
    - `L::Lattice{N}`: The original lattice to be downsampled.
    - `n::Int`: The downsample factor for each dimension of the lattice.

    # Returns
    - `Tuple`: A tuple of downsampled ranges corresponding to each dimension of the lattice.

    # Errors
    Throws `DomainError` if `n` does not evenly divide the length of each dimension of `L`.
    """
function downsample(L::Lattice{N}, n::Int) where {N}
    # Downsamples a lattice L by merging n^N points into one, centered at the mean of the original points.
    # n must divide the length of each dimension of L. 
    return ((downsample(l, n) for l in L)...,)
end

"""
    downsample(L::Lattice{N}, ns::NTuple{N,Int}) where N

    Downsample a lattice `L` with different downsampling factors for each dimension, merging `ns[1]×ns[2]×...×ns[N]` 
    points into one, centered at the mean of the original points. This allows for non-uniform downsampling of a lattice.

    # Arguments
    - `L::Lattice{N}`: The original lattice to be downsampled.
    - `ns::NTuple{N,Int}`: A tuple specifying the downsampling factor for each dimension of the lattice.

    # Returns
    - `Tuple`: A tuple of downsampled ranges, each corresponding to a dimension of the lattice with its own downsampling factor.

    # Errors
    Throws `DomainError` if `ns[i]` does not evenly divide the length of `L[i]` for `i=1:N`.
    """
function downsample(L::Lattice{N}, ns::NTuple{N,Int}) where {N}
    # Downsamples a lattice L by merging ns[1]×ns[2]×⋯×ns[N] points into one, centered at the mean of the original points.
    # ns[i] must divide the length of L[i] for i=1:N. 
    return ((downsample(L[i], ns[i]) for i = 1:N)...,)
end

#endregion

#region -------------------downsample arrays -------------------------------

"""
    downsample(x::AbstractArray{T,N}, Lu::Lattice{N}, Ld::Lattice{N}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {T<:Number,N}

    Downsample an `AbstractArray` from a fine lattice `Ld` to a coarse lattice `Lu`. This function does not require any specific relationship between the lattices; it simply interpolates `x` from one lattice to the other.

    # Arguments
    - `x::AbstractArray{T,N}`: The original array on lattice `Ld`.
    - `Lu::Lattice{N}`: The coarse lattice to downsample to.
    - `Ld::Lattice{N}`: The fine lattice representing the original array's grid.
    - `interpolation`: The interpolation method to use (default is cubic spline interpolation).
    - `bc`: Boundary conditions to use (default is zero).

    # Returns
    - `AbstractArray`: The downsampled array.

    # Errors
    Throws `DomainError` if the size of `x` does not match the size of `Lu`.
    """
function downsample(x::AbstractArray{T,N}, Lu::Lattice{N}, Ld::Lattice{N}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {T<:Number,N}
    # This lattice downsampler is basically the same as the upsampler with the roles of Lu and Ld reversed. 
    # Downsamples an array from fine lattice Ld to coarse lattice Lu.  Actually, there doesn't need to be any relationship
    # between the lattices at all--this function just interpolates x from one lattice to the other. 
    if size(x) != length.(Lu)
        throw(DomainError((size(x), length.(Lu)), "downsample: Size of array x does not match size of lattice Lu."))
    end
    return interpolation(Lu, x, extrapolation_bc=bc)[Ld...]
end

"""
    downsample(x::AbstractArray{T,N}, n::Int; interpolation=cubic_spline_interpolation, bc=zero(T)) where {T<:Number,N}

    Downsample an `AbstractArray` to a grid that is `n` times coarser. This is achieved by interpolating the array from its original lattice to a coarser lattice with a downsample factor of `n`.

    # Arguments
    - `x::AbstractArray{T,N}`: The original array to be downsampled.
    - `n::Int`: The downsample factor.
    - `interpolation`: The interpolation method to use (default is cubic spline interpolation).
    - `bc`: Boundary conditions to use (default is zero).

    # Returns
    - `AbstractArray`: The downsampled array.
"""
function downsample(x::AbstractArray{T,N}, n::Int; interpolation=cubic_spline_interpolation, bc=zero(T)) where {T<:Number,N}
    # Downsamples an array from to a grid that is n times coarser, i.e. a grid downsampled by n.
    Lu = ((1:s for s in size(x))...,)
    Ld = downsample(Lu, n)
    return downsample(x, Lu, Ld; interpolation=interpolation, bc=bc)
end

"""
    downsample(x::AbstractArray{T,N}, ns::NTuple{N,Int}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {T<:Number,N}

Downsample an `AbstractArray` to a grid with different coarsening factors for each dimension, specified by `ns`.

# Arguments
- `x::AbstractArray{T,N}`: The original array to be downsampled.
- `ns::NTuple{N,Int}`: A tuple specifying the downsample factor for each dimension of the array.
- `interpolation`: The interpolation method to use (default is cubic spline interpolation).
- `bc`: Boundary conditions to use (default is zero).

# Returns
- `AbstractArray`: The downsampled array.
"""
function downsample(x::AbstractArray{T,N}, ns::NTuple{N,Int}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {T<:Number,N}
    # Downsamples an array from to a grid that is n times coarser, i.e. a grid downsampled by n.
    Lu = ((1:s for s in size(x))...,)
    Ld = downsample(Lu, ns)
    return downsample(x, Lu, Ld; interpolation=interpolation, bc=bc)
end

#endregion

#region -------------------downsample fields -------------------------------

"""
    downsample(f::LatticeField{S,T,N}, Ld::Lattice{N}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {S<:FieldVal,T<:Number,N}

    Downsample a `LatticeField` to a specified lattice `Ld`. This function interpolates the field data from its original lattice to the new lattice `Ld`.

    # Arguments
    - `f::LatticeField{S,T,N}`: The original lattice field to be downsampled.
    - `Ld::Lattice{N}`: The target lattice for downsampling.
    - `interpolation`: The interpolation method to use (default is cubic spline interpolation).
    - `bc`: Boundary conditions to use (default is zero).

    # Returns
    - `LatticeField{S}`: The downsampled lattice field.
    """
function downsample(f::LatticeField{S,T,N}, Ld::Lattice{N}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {S<:FieldVal,T<:Number,N}
    # Downsamples field f to lattice Lu.  Actually, there doesn't need to be any relationship
    # between the lattices at all--this function just interpolates x from one lattice to the other. 
    return LatticeField{S}(downsample(f.data, f.L, Ld; interpolation=interpolation, bc=bc), Ld, f.flambda)
end
vandyfooo=0


"""
    downsample(f::LatticeField{S,T,N}, n::Int; interpolation=cubic_spline_interpolation, bc=zero(T)) where {S<:FieldVal,T<:Number,N}

    Downsample a `LatticeField` to a grid that is `n` times coarser in each dimension.

    # Arguments
    - `f::LatticeField{S,T,N}`: The original lattice field to be downsampled.
    - `n::Int`: The uniform downscaling factor.
    - `interpolation`: The interpolation method to use (default is cubic spline interpolation).
    - `bc`: Boundary conditions to use (default is zero).

    # Returns
    - `LatticeField{S}`: The downsampled lattice field.
    """
function downsample(f::LatticeField{S,T,N}, n::Int; interpolation=cubic_spline_interpolation, bc=zero(T)) where {S<:FieldVal,T<:Number,N}
    # Downsamples field f to a grid that is n times coarser, i.e. a grid downsampled by n.
    Ld = downsample(f.L, n)
    return LatticeField{S}(downsample(f.data, f.L, Ld; interpolation=interpolation, bc=bc), Ld, f.flambda)
end

"""
    downsample(f::LatticeField{S,T,N}, ns::NTuple{N,Int}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {S<:FieldVal,T<:Number,N}

    Downsample a `LatticeField` to a grid with different coarsening factors for each dimension, specified by `ns`. 

    # Arguments
    - `f::LatticeField{S,T,N}`: The original lattice field to be downsampled.
    - `ns::NTuple{N,Int}`: A tuple specifying the downscaling factor for each dimension of the lattice field.
    - `interpolation`: The interpolation method to use (default is cubic spline interpolation).
    - `bc`: Boundary conditions to use (default is zero).

    # Returns
    - `LatticeField{S}`: The downsampled lattice field.
    """
function downsample(f::LatticeField{S,T,N}, ns::NTuple{N,Int}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {S<:FieldVal,T<:Number,N}
    # Downsamples an array to a grid that is ns[i] times coarser in dimension i, i.e. a grid downsampled by n.
    Ld = downsample(f.L, ns)
    return LatticeField{S}(downsample(f.data, f.L, Ld; interpolation=interpolation, bc=bc), Ld, f.flambda)
end

#endregion

#region -------------------- coarsen (downsampling by averaging)--------------------------------

"""
    coarsen(x::AbstractArray{T,N}, ns::NTuple{N,Int}; reducer=(x::AbstractArray -> sum(x)/length(x[:]))) where {T<:Number,N}

    Coarsen (downsample) an `AbstractArray` to a grid that is `ns[i]` times coarser in dimension `i`, using a reduction function over superpixels. Unlike interpolation-based downsampling, this method averages over blocks (superpixels) of the array.
	
    # Arguments
    - `x::AbstractArray{T,N}`: The original array to be coarsened.
    - `ns::NTuple{N,Int}`: A tuple specifying the coarsening factor for each dimension.
    - `reducer`: The function used to reduce each superpixel (default is average).

    # Returns
    - `Array`: The coarsened array.

    # Errors
    Throws `DomainError` if the `ns` factors do not evenly divide the size of `x`.
    """
function coarsen(x::AbstractArray{T,N}, ns::NTuple{N,Int}; reducer=(x::AbstractArray -> sum(x) / length(x[:]))) where {T<:Number,N}
    # This is also a downsampler, but it averages over superpixels, rather than interpolating. 
    # Downsamples an array to a grid that is ns[i] times coarser in dimension i, i.e. a grid downsampled by ns, 
    # reducing superpixels via the supplied function reducer. 
    sx = size(x)
    if sx .% ns != size(x) .* 0
        throw(DomainError((sx, ns), "coarsen: Downsample factors ns do not divide the size of array x."))
    end
    box = CartesianIndices(ns) .- CartesianIndex((1 for i = 1:N)...)
    CI = CartesianIndices(((1:ns[i]:size(x)[i] for i = 1:N)...,))
    return [reducer(x[I.+box]) for I in CI]
end

"""
    coarsen(x::AbstractArray{T,N}, n::Int; reducer=(x::AbstractArray -> sum(x)/length(x[:]))) where {T<:Number,N}

    Coarsen (downsample) an `AbstractArray` to a grid that is uniformly `n` times coarser in each dimension, using a reduction function over superpixels. This function is a specialized form of the `coarsen` method for cases where a uniform downsampling across all dimensions is desired. 

    # Arguments
    - `x::AbstractArray{T,N}`: The original array to be coarsened.
    - `n::Int`: The uniform coarsening factor for each dimension.
    - `reducer`: The function used to reduce each superpixel (default is average).

    # Returns
    - `Array`: The coarsened array.
    """
function coarsen(x::AbstractArray{T,N}, n::Int; reducer=(x::AbstractArray -> sum(x) / length(x[:]))) where {T<:Number,N}
    # Downsamples an array to a grid that is n times coarser, i.e. a grid downsampled by n, reducing superpixels via the supplied function reducer. 
    return coarsen(x, ((n for i = 1:N)...,); reducer=reducer)
end

"""
    coarsen(f::LatticeField{S,T,N}, ns::NTuple{N,Int}; reducer=(x::AbstractArray -> sum(x)/length(x[:]))) where {S<:FieldVal,T<:Number,N}

    Coarsen (downsample) a `LatticeField` to a grid that is `ns[i]` times coarser in dimension `i`, using a reduction function over superpixels. This method differs from interpolation-based downsampling by averaging over blocks (superpixels) of the lattice field. 

    # Arguments
    - `f::LatticeField{S,T,N}`: The original lattice field to be coarsened.
    - `ns::NTuple{N,Int}`: A tuple specifying the coarsening factor for each dimension.
    - `reducer`: The function used to reduce each superpixel (default is average).

    # Returns
    - `LatticeField{S}`: The coarsened lattice field.
    """
function coarsen(f::LatticeField{S,T,N}, ns::NTuple{N,Int}; reducer=(x::AbstractArray -> sum(x) / length(x[:]))) where {S<:FieldVal,T<:Number,N}
    # Downsamples field f to a grid that is ns[i] times coarser in dimension i, i.e. a grid downsampled by ns, 
    # reducing superpixels via the supplied function reducer. 
    Ld = downsample(f.L, ns)
    return LatticeField{S}(coarsen(f.data, ns; reducer=reducer), Ld, f.flambda)
end

"""
    coarsen(f::LatticeField{S,T,N}, n::Int; reducer=(x::AbstractArray -> sum(x)/length(x[:]))) where {S<:FieldVal,T<:Number,N}

    Coarsen (downsample) a `LatticeField` to a grid that is uniformly `n` times coarser in each dimension, using a reduction function over superpixels. 

    # Arguments
    - `f::LatticeField{S,T,N}`: The original lattice field to be coarsened.
    - `n::Int`: The uniform coarsening factor for each dimension.
    - `reducer`: The function used to reduce each superpixel (default is average).

    # Returns
    - `LatticeField{S}`: The coarsened lattice field.
    """
function coarsen(f::LatticeField{S,T,N}, n::Int; reducer=(x::AbstractArray -> sum(x) / length(x[:]))) where {S<:FieldVal,T<:Number,N}
    # Downsamples an array from to a grid that is n times coarser, i.e. a grid downsampled by n, reducing superpixels via the supplied function reducer. 
    Ld = downsample(f.L, n)
    return LatticeField{S}(coarsen(f.data, n; reducer=reducer), Ld, f.flambda)
end


#endregion

#region --------------------upsample lattices----------------------------

"""
    upsample(r::AbstractRange, n::Int)

    Upsample a range `r`, effectively replacing each original point in the range with `n` points,
    centered around the original point.

    # Arguments
    - `r::AbstractRange`: The original range to be upsampled.
    - `n::Int`: The number of points to replace each original point in the range.

    # Returns
    - `AbstractRange`: A new range with each original point replaced by `n` points.
    """
function upsample(r::AbstractRange, n::Int)
    # Upsamples a range r, replacing each original point by n points, centered on the original. 
    return ((1:length(r)*n) .- (1 + n) / 2) .* (step(r) / n) .+ r[1]
end

"""
    upsample(L::Lattice{N}, n::Int) where {N}

    Upsample a lattice `L`, replacing each original pixel by `n^N` pixels.

    # Arguments
    - `L::Lattice{N}`: The original lattice to be upsampled.
    - `n::Int`: The upscaling factor for each dimension of the lattice.

    # Returns
    - `Tuple`: A tuple of upsampled ranges corresponding to each dimension of the lattice.
    """
function upsample(L::Lattice{N}, n::Int) where {N}
    # Upsamples a lattice, replacing each original pixel by n^N pixels, centered on the original. 
    return ((upsample(l, n) for l in L)...,)
end

"""
    upsample(L::Lattice{N}, ns::NTuple{N,Int}) where {N}

    Upsample a lattice `L` with different scaling factors for each dimension. 

    # Arguments
    - `L::Lattice{N}`: The original lattice to be upsampled.
    - `ns::NTuple{N,Int}`: A tuple specifying the upscaling factor for each dimension of the lattice.

    # Returns
    - `Tuple`: A tuple of upsampled ranges, each corresponding to a dimension of the lattice with its 
    own scaling factor.
    """
function upsample(L::Lattice{N}, ns::NTuple{N,Int}) where {N}
    # Upsamples a lattice, replacing each original pixel by n^N pixels, centered on the original. 
    return ((upsample(L[i], ns[i]) for i = 1:N)...,)
end

#endregion

#region ---------------------upsample array--------------------------------
"""
    upsample(f::LatticeField{S,T,N}, Lu::Lattice{N}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {S<:FieldVal,T<:Number,N}

    Upsamples a `LatticeField` instance to a new lattice `Lu`. This function interpolates the data from the 
    original lattice of `f` to the new lattice `Lu` using the specified interpolation method and boundary conditions.

    # Parameters
    - `f`: An instance of `LatticeField` to be upsampled.
    - `Lu`: The new lattice to which the field will be upsampled.
    - `interpolation`: The interpolation method used for upsampling. Defaults to `cubic_spline_interpolation`.
    - `bc`: Boundary conditions for the interpolation. Defaults to `zero(T)`, where T is the relevant numerical type.

    # Returns
    A new `LatticeField` instance with data upsampled to the lattice `Lu`.
    """
function upsample(x::AbstractArray{T,N}, Ld::Lattice{N}, Lu::Lattice{N}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {T<:Number,N}
    # Upsamples an array from coarse lattice Ld to fine lattice Lu.  Actually, there doesn't need to be any relationship
    # between the lattices at all--this function just interpolates x from one lattice to the other. 
    if size(x) != length.(Ld)
        throw(DomainError((size(x), length.(Ld)), "upsample: Size of array x does not match size of lattice Ld."))
    end
    return interpolation(Ld, x, extrapolation_bc=bc)[Lu...]
end

"""
    upsample(x::AbstractArray{T,N}, n::Int; interpolation=cubic_spline_interpolation, bc=zero(T)) where {T<:Number,N}

    Upsample an `AbstractArray` to a grid that is `n` times finer. 

    # Arguments
    - `x::AbstractArray{T,N}`: The original array to be upsampled.
    - `n::Int`: The factor by which the grid resolution is increased.
    - `interpolation`: The interpolation method to use (default is cubic spline interpolation).
    - `bc`: Boundary conditions to use (default is zero).

    # Returns
    - `AbstractArray`: The upsampled array.
    """
function upsample(x::AbstractArray{T,N}, n::Int; interpolation=cubic_spline_interpolation, bc=zero(T)) where {T<:Number,N}
    # Upsamples an array from to a grid that is n times finer, i.e. a grid upsampled by n.
    Ld = ((1:s for s in size(x))...,)
    Lu = upsample(Ld, n)
    return upsample(x, Ld, Lu; interpolation=interpolation, bc=bc)
end


"""
    upsample(x::AbstractArray{T,N}, ns::NTuple{N,Int}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {T<:Number,N}

    Upsample an `AbstractArray` to a grid with different upscaling factors for each dimension, allowing for non-uniform upscaling. 

    # Arguments
    - `x::AbstractArray{T,N}`: The original array to be upsampled.
    - `ns::NTuple{N,Int}`: A tuple specifying the upscaling factor for each dimension of the array.
    - `interpolation`: The interpolation method to use (default is cubic spline interpolation).
    - `bc`: Boundary conditions to use (default is zero).

    # Returns
    - `AbstractArray`: The upsampled array.
    """
function upsample(x::AbstractArray{T,N}, ns::NTuple{N,Int}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {T<:Number,N}
    # Upsamples an array from to a grid that is n times finer, i.e. a grid upsampled by n.
    Ld = ((1:s for s in size(x))...,)
    Lu = upsample(Ld, ns)
    return upsample(x, Ld, Lu; interpolation=interpolation, bc=bc)
end
#endregion

#region -------------------upsample fields -------------------------------

"""
    upsample(f::LatticeField{S,T,N}, Lu::Lattice{N}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {S<:FieldVal,T<:Number,N}

    Upsample a `LatticeField` to a specified lattice `Lu`. This function interpolates the field data from its original lattice to the new lattice `Lu`. 

    # Arguments
    - `f::LatticeField{S,T,N}`: The original lattice field to be upsampled.
    - `Lu::Lattice{N}`: The target lattice for upsampling.
    - `interpolation`: The interpolation method to use (default is cubic spline interpolation).
    - `bc`: Boundary conditions to use (default is zero).

    # Returns
    - `LatticeField{S}`: The upsampled lattice field.
    """
function upsample(f::LatticeField{S,T,N}, Lu::Lattice{N}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {S<:FieldVal,T<:Number,N}
    # Upsamples field f to lattice Lu.  Actually, there doesn't need to be any relationship
    # between the lattices at all--this function just interpolates x from one lattice to the other. 
    return LatticeField{S}(upsample(f.data, f.L, Lu; interpolation=interpolation, bc=bc), Lu, f.flambda)
end

"""
    upsample(f::LatticeField{S,T,N}, n::Int; interpolation=cubic_spline_interpolation, bc=zero(T)) where {S<:FieldVal,T<:Number,N}

    Upsample a `LatticeField` to a grid that is `n` times finer. 

    # Arguments
    - `f::LatticeField{S,T,N}`: The original lattice field to be upsampled.
    - `n::Int`: The uniform upscaling factor.
    - `interpolation`: The interpolation method to use (default is cubic spline interpolation).
    - `bc`: Boundary conditions to use (default is zero).

    # Returns
    - `LatticeField{S}`: The upsampled lattice field.
    """
function upsample(f::LatticeField{S,T,N}, n::Int; interpolation=cubic_spline_interpolation, bc=zero(T)) where {S<:FieldVal,T<:Number,N}
    # Upsamples field f to a grid that is n times finer, i.e. a grid upsampled by n.
    Lu = upsample(f.L, n)
    return upsample(f, Lu; interpolation=interpolation, bc=bc)
end

"""
    upsample(f::LatticeField{S,T,N}, ns::NTuple{N,Int}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {S<:FieldVal,T<:Number,N}

    Upsample a `LatticeField` to a grid with different upscaling factors for each dimension, specified by `ns`. 

    # Arguments
    - `f::LatticeField{S,T,N}`: The original lattice field to be upsampled.
    - `ns::NTuple{N,Int}`: A tuple specifying the upscaling factor for each dimension of the lattice field.
    - `interpolation`: The interpolation method to use (default is cubic spline interpolation).
    - `bc`: Boundary conditions to use (default is zero).

    # Returns
    - `LatticeField{S}`: The upsampled lattice field.
    """
function upsample(f::LatticeField{S,T,N}, ns::NTuple{N,Int}; interpolation=cubic_spline_interpolation, bc=zero(T)) where {S<:FieldVal,T<:Number,N}
    # Upsamples an array from to a grid that is ns[i] times finer in dimension i, i.e. a grid upsampled by n.
    Lu = upsample(f.L, ns)
    return upsample(f, Lu; interpolation=interpolation, bc=bc)
end

#endregion



end