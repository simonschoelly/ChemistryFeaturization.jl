using ..ChemistryFeaturization.Utils.AtomFeatureUtils

#=
Feature of a single atom.

May be contextual (depends on neighborhood) or elemental (defined just by the atomic identity of the node).
=#
# proper docstring
# TODO: add way to get range/list of possible values for feature...
struct AtomFeature <: AbstractFeature
    name::String
    encode_f::Any
    decode_f::Any
    categorical::Bool
    contextual::Bool # can get from elemental lookup table (false) or not (true)?
    length::Int # length of encoded vector
    encodable_elements::Vector{String}
end

# pretty printing, short version
Base.show(io::IO, af::AtomFeature) = print(io, "AtomFeature $(af.name)")

# pretty printing, long version
function Base.show(io::IO, ::MIME"text/plain", af::AtomFeature)
    st = "AtomFeature $(af.name):\n   categorical: $(af.categorical)\n   contextual: $(af.contextual)\n   encoded length: $(af.length)"
    print(io, st)
end

# docstring
function AtomFeature(
    feature_name;
    nbins = default_nbins,
    logspaced = default_log[feature_name],
)
    @assert feature_name in continuous_feature_names ||
            feature_name in categorical_feature_names "Cannot automatically build AtomFeat for $feature_name; I can't find it in a lookup table!"
    local vector_length
    categorical = feature_name in categorical_feature_names
    if categorical
        vector_length = length(categorical_feature_vals[feature_name])
    else
        vector_length = nbins
    end
    encode_f =
        atoms -> reduce(
            hcat,
            map(
                e -> onehot_lookup_encoder(
                    e,
                    feature_name;
                    nbins = nbins,
                    logspaced = logspaced,
                ),
                atoms.elements,
            ),
        )
    decode_f =
        encoded ->
            onecold_decoder(encoded, feature_name; nbins = nbins, logspaced = logspaced)
    AtomFeature(feature_name, encode_f, decode_f, categorical, false, vector_length, ChemistryFeaturization.Utils.AtomFeatureUtils.encodable_elements(feature_name))
end

# TODO: some Weave stuff needed here
