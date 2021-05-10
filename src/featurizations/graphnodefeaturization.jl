# TODO: proper docstring
#=
Featurization for `AtomGraph` objects that featurizes graph nodes only.
=#
export GraphNodeFeaturization
export featurize!
export encodable_elements

struct GraphNodeFeaturization <: AbstractFeaturization
    atom_features::Vector{AtomFeature}
end

# docstring
function GraphNodeFeaturization(
    feature_names::Vector{String};
    nbins = length.(get_bins.(feature_names)),
    logspaced = getindex.(Ref(default_log), feature_names),
)
    afs = map(zip(feature_names, nbins, logspaced)) do args
        AtomFeature(args[1], nbins = args[2], logspaced = args[3])
    end
    GraphNodeFeaturization(afs)
end

# TODO: function to compute total vector length

# docstring
encodable_elements(fzn::GraphNodeFeaturization) = intersect([f.encodable_elements for f in fzn.atom_features]...)

# docstring
function featurize!(a::AbstractAtoms, fzn::GraphNodeFeaturization)
    # check that all elements are encodable
    @assert all(map(el -> el in encodable_elements(fzn), a.elements)) "Some atoms in your structure are not encodable by this featurization!"
    # then use the generic one
    invoke(featurize!, Tuple{AbstractAtoms, AbstractFeaturization}, a, fzn)
end