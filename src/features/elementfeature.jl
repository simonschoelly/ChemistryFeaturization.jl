using ..ChemistryFeaturization.Utils.ElementFeatureUtils
using DataFrames

using ..ChemistryFeaturization.AbstractType: AbstractCodec, AbstractAtoms
using ..ChemistryFeaturization.Codec: OneHotOneCold, EncodeOrDecode, ENCODE, DECODE

include("abstractfeatures.jl")


# TODO - consider edge cases in constructor. add this stuff into modulify.

# TODO: figure out what scheme would look like that is flexible to direct-value encoding (may just need a different feature type since it'll have to handle normalization, etc. too)
"""
    ElementFeatureDescriptor(feature_name, encode_f, decode_f, categorical, contextual, length, encodable_elements)

Construct a feature object that encodes features associated with individual atoms that depend only upon their elemental identity (if you want to encode a feature that depends upon an atom's environment, you shold use SpeciesFeatureDescriptor!)

## Arguments
- `name::String`: the name of the feature
- `categorical::Bool`: flag for whether the feature is categorical or continuous-valued
- `length::Int`: length of encoded vector
- `logspaced::Bool`: whether onehot-style bins should be logarithmically spaced or not
- `lookup_table::DataFrame`: table containing values of feature for every encodable element
"""
struct ElementFeatureDescriptor <: AbstractAtomFeatureDescriptor
    name::String
    encoder_decoder::AbstractCodec
    categorical::Bool
    lookup_table::DataFrame
end

function ElementFeatureDescriptor(
    feature_name::String,
    lookup_table::DataFrame = atom_data_df;
    nbins::Integer = default_nbins,
    logspaced::Bool = default_log(feature_name, lookup_table),
    categorical::Bool = default_categorical(feature_name, lookup_table),
)
    colnames = names(lookup_table)
    @assert feature_name in colnames && "Symbol" in colnames "Your lookup table must have a column called :Symbol and one with the same name as your feature to be usable!"

    lookup_table = lookup_table[:, ["Symbol", feature_name]]
    dropmissing!(lookup_table)

    ElementFeatureDescriptor(
        feature_name,
        OneHotOneCold(default_efd_encode, default_efd_decode, nbins, logspaced),
        categorical,
        lookup_table,
    )
end

# pretty printing, short version
Base.show(io::IO, efd::ElementFeatureDescriptor) = print(io, "ElementFeature $(efd.name)")

# pretty printing, long version
function Base.show(io::IO, ::MIME"text/plain", efd::ElementFeatureDescriptor)
    st = "ElementFeature $(efd.name):\n   categorical: $(efd.categorical)\n   encoded length: $(output_shape(efd))"
    print(io, st)
end

encodable_elements(efd::ElementFeatureDescriptor) = efd.lookup_table[:, :Symbol]

function encodable_elements(feature_name::String, lookup_table::DataFrame = atom_data_df)
    info = lookup_table[:, [Symbol(feature_name), :Symbol]]
    return info[
        findall(x -> !ismissing(x), getproperty(info, Symbol(feature_name))),
        :Symbol,
    ]
end

function (efd::ElementFeatureDescriptor)(a::AbstractAtoms)
    @assert all([el in encodable_elements(efd) for el in a.elements]) "Feature $(efd.name) cannot encode some element(s) in this structure!"
    efd.encoder_decoder(efd, a, ENCODE)
end

encode(efd::ElementFeatureDescriptor, a::AbstractAtoms) =
    efd.encoder_decoder(efd, a, ENCODE)
decode(efd::ElementFeatureDescriptor, encoded_feature) =
    efd.encoder_decoder(efd, encoded_feature)

function (ed::OneHotOneCold)(
    efd::ElementFeatureDescriptor,
    a::AbstractAtoms,
    e_or_d::EncodeOrDecode,
)
    if e_or_d == ENCODE
        ed.encode_f(efd, a, ed.nbins, ed.logspaced)
    else
        ed.decode_f(efd, a, ed.nbins, ed.logspaced)
    end
end

output_shape(efd::ElementFeatureDescriptor) = output_shape(efd, efd.encoder_decoder)

function output_shape(efd::ElementFeatureDescriptor, ed::OneHotOneCold)
    return efd.categorical ? length(unique(efd.lookup_table[:, Symbol(efd.name)])) :
           ed.nbins
end

function (ed::OneHotOneCold)(efd::ElementFeatureDescriptor, encoded_feature)
    ed.decode_f(efd, encoded_feature, ed.nbins, ed.logspaced)
end

function default_efd_encode(
    efd::ElementFeatureDescriptor,
    a::AbstractAtoms,
    nbins::Integer,
    logspaced::Bool,
)
    reduce(
        hcat,
        map(
            e -> onehot_lookup_encoder(
                e,
                efd.name,
                efd.lookup_table;
                nbins = nbins,
                logspaced = logspaced,
                categorical = efd.categorical,
            ),
            a.elements,
        ),
    )
end


default_efd_decode(efd::ElementFeatureDescriptor, encoded_feature, nbins, logspaced) =
    onecold_decoder(
        encoded_feature,
        efd.name,
        efd.lookup_table;
        nbins = nbins,
        logspaced = logspaced,
        categorical = efd.categorical,
    )
