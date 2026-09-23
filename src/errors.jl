"""
    UnsupportedError(msg, alternative = "")

Thrown when a valid input combination is not supported by the requested method.
"""
struct UnsupportedError <: Exception
    msg::String
    alternative::String
end

UnsupportedError(msg::AbstractString) = UnsupportedError(msg, "")

function Base.showerror(io::IO, e::UnsupportedError)
    print(io, "UnsupportedError: ", e.msg)
    isempty(e.alternative) || print(io, "\nAlternative: ", e.alternative)
    return nothing
end
