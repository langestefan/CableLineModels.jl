_floats(xs...) = map(float, promote(xs...))

function _check_finite(context, values::NamedTuple)
    for (field, x) in pairs(values)
        isfinite(x) || throw(ArgumentError("$context: $field must be finite, got $x"))
    end
    return nothing
end

_fits_outside(r_in, r) = (r_in - r) / r >= -1.0e-6
