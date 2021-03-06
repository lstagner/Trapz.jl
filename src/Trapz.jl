module Trapz
    export trapz


    @inline function bringlast(T::Tuple,el)
        ifelse(el==T[1],
            (bringlast(Base.tail(T),el)...,T[1]) ,
            (T[1],bringlast(Base.tail(T),el)...)
        )
    end
    @inline function bringlast(T::Tuple{},el); T; end

    @inline function trapz_colon(k) Colon(); end
    @inline function idxlast(i,::Val{N}) where N; Base.tail((ntuple(trapz_colon,Val(N))...,i)) end
    function killzerodim(A::AbstractArray{fT,0}) where fT
        A[]
    end
    function killzerodim(A::AbstractArray{fT,N}) where {fT,N}
        A
    end
    function killzerodim(A::fT) where {fT<:Number}
        A
    end
    function trapz(x::T1, y::T2) where {N,fT,T1<:AbstractVector{fT},T2<:AbstractArray{fT,N}}
        n = length(x)
        s = size(y)
        @assert s[end]==n
        @inbounds begin
            r = similar(y,Base.reverse(Base.tail(Base.reverse(s))))
            if n <= 1;
                r.=zero(fT)
                @goto retval;
            end
            @fastmath r .= (x[2] - x[1]) .* view(y,idxlast(1,Val(N))...)
            for i in 2:n-1
               @fastmath r .+= (x[i+1] - x[i-1]) .* view(y,idxlast(i,Val(N))...)
            end
            @fastmath r .+= (x[end]-x[end-1]) .* view(y,idxlast(n,Val(N))...)
            @label retval
            return killzerodim(r./2)
        end
    end

    function trapz(x::T1, y::T2, axis::T3) where {N,fT,T1<:AbstractVector{fT},T2<:AbstractArray{fT,N},T3<:Integer}
        @assert 1<=axis<=N
        trapz(x,PermutedDimsArray(y,bringlast(ntuple(identity,Val(N)),axis)))
    end

    function gen_trapz_impl(xs::Type{T}, M) where T <: NTuple{N} where N
        ex = :(trapz(xs[$N], M))
        for i=(N-1):-1:1
            ex = :(trapz(xs[$i],$ex))
        end
        return ex
    end

    @generated function trapz(xs::NTuple{N}, M) where N
        return gen_trapz_impl(xs, M)
    end

    function trapz(xs::NTuple{N}, M::AbstractArray{T,S}, axes::NTuple{N}) where {N, T, S}
        if S > N
            axes = ((i for i=1:S if !in(i,axes))..., axes...)
        end
        trapz(xs, PermutedDimsArray(M, axes))
    end

    """
        trapz(x,y,axis=End)
        Calculates ∫y[..., i (axis) ,...] dx[i]
        for performance reasons x must have the same float type as y.
        1-D Example:
    ```julia
        vx=0:0.01:1
        vy=(x->x^2).(vx)
        trapz(vx,vy)
    ```
            Result ≈ 1/3

        2-D Example:
    ```julia
        vx=0:0.01:1
        vy=0:0.01:2
        z=[x^2+y^2 for x=vx, y=vy]
        trapz((vx,vy),z) # equivalent to trapz(vx, trapz(vy, z))
    ```
            Result ≈ 4/3

        2-D Example in reverse integration order:
    ```julia
        vx=0:0.01:1
        vy=0:0.01:2
        z=[x^2+y^2 for x=vx, y=vy]
        trapz((vy,vx),z,(2,1)) # equivalent to trapz(vy, trapz(vx, z, 1), 1)
    ```
            Result ≈ 4/3
    """
    trapz


end # module


#Some testing code
# using BenchmarkTools,GPUArrays
#
# vx=range(0,1,length=100)
# vy=vx.^2
# My=[x^2+y^2 for x in vx,y in vx]
# Ty=[x^2+y^2+z^2 for x in vx,y in vx,z in vx]
#
#
# Main.Trapz.trapz(vx,JLArray(Ty))
# Main.Trapz.trapz(vx,JLArray(My))
# Main.Trapz.trapz(vx,JLArray(vy))
# Main.Trapz.trapz(vx,My)
# Main.Trapz.trapz(vx,Ty)
# Main.Trapz.trapz(vx,vy)
#
