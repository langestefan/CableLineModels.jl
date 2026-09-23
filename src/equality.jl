const _ValueTypes = Union{
    Material, Conductor, Annulus, WireGeometry, Layer, CableCore, FourCoreLV, CableDesign,
    PlacedCable, InDuct, EarthModel, CableSystem,
}

_fields(x) = ntuple(i -> getfield(x, i), Val(fieldcount(typeof(x))))
_same_kind(a, b) = nameof(typeof(a)) === nameof(typeof(b))

Base.:(==)(a::_ValueTypes, b::_ValueTypes) = _same_kind(a, b) && _fields(a) == _fields(b)
Base.isequal(a::_ValueTypes, b::_ValueTypes) = _same_kind(a, b) && isequal(_fields(a), _fields(b))
Base.hash(x::_ValueTypes, h::UInt) = hash(_fields(x), hash(nameof(typeof(x)), h))
