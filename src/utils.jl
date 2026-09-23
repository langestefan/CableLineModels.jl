_numtype_of(x::Real) = typeof(x)
_numtype_of(::Nothing) = Union{}
_numtype_of(x) = numtype(x)
_promote_numtype(xs...) = float(promote_type(map(_numtype_of, xs)...))

_eltype_numtype(v::AbstractVector) = mapreduce(numtype, promote_type, v; init = Union{})

function _check_finite(context, values::NamedTuple)
    for (field, x) in pairs(values)
        isfinite(x) || throw(ArgumentError("$context: $field must be finite, got $x"))
    end
    return nothing
end

_fits_outside(r_in, r) = (r_in - r) / r >= -1.0e-6
