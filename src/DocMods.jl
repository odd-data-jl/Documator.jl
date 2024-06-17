abstract type DocServable end

mutable struct DocModule <: DocServable
    name::String
    color::String
    pages::Vector{Component{<:Any}}
    projectpath::String
end

mutable struct DocSystem <: DocServable
    name::String
    modules::Vector{DocModule}
    ecodata::Dict{String, Any}
end

getindex(dc::Vector{<:DocServable}, ref::AbstractString) = begin
    pos = findfirst(cl::DocServable -> cl.name == ref, dc)
    if isnothing(pos)
        throw("$ref was not in here")
    end
    dc[pos]::DocServable
end

abstract type AbstractDocClient end


getindex(dc::Vector{<:AbstractDocClient}, ref::AbstractString) = begin
    pos = findfirst(cl::AbstractDocClient -> cl.key == ref, dc)
    if isnothing(pos)

    end
    dc[pos]::AbstractDocClient
end

function read_doc_config(path::String, mod::Module = Main)
    data = TOML.parse(read(path * "/config.toml", String))
    docsystems::Vector{DocSystem} = Vector{DocSystem}()
    for ecosystem in data
        ecodata = ecosystem[2]
        name = ecosystem[1]
        mods = reverse(Vector{DocModule}(filter(k -> ~(isnothing(k)), [begin
            docmod_from_data(dct[1], dct[2], mod, path)
        end for dct in filter(k -> typeof(k[2]) <: AbstractDict, ecodata)])))
        push!(docsystems, 
        DocSystem(name, mods, Dict{String, Any}(ecodata)))
    end
    reverse(docsystems)::Vector{DocSystem}
end

JULIA_HIGHLIGHTER = OliveHighlighters.TextStyleModifier()
OliveHighlighters.julia_block!(JULIA_HIGHLIGHTER)
style!(JULIA_HIGHLIGHTER, :default, ["color" => "white"])
style!(JULIA_HIGHLIGHTER, :funcn, ["color" => "lightblue"])

function julia_interpolator(raw::String)
    tm = JULIA_HIGHLIGHTER
    set_text!(tm, raw)
    OliveHighlighters.mark_julia!(tm)
    ret::String = string(tm)
    OliveHighlighters.clear!(tm)
    jl_container = div("jlcont", text = ret)
    style!(jl_container, "background-color" => "#333333", "font-size" => 12pt, "padding" => 7px)
    string(jl_container)::String
end

html_interpolator(raw::String) = OliveHighlighters.rep_in(raw)::String

function img_interpolator(raw::String)
    if contains(raw, "|")
        splits = split(raw, "|")
        if length(splits) == 3
            return(string(div(Components.gen_ref(3), align = splits[2], 
            children = [img(Components.gen_ref(3), src = splits[3], width = splits[1])])))::String
        end
        return(string(img(Components.gen_ref(3), src = splits[2], width = splits[1])))::String
    end
    string(img(Components.gen_ref(3), src = raw))::String
end

function docmod_from_data(name::String, dct_data::Dict{String, <:Any}, mod::Module, path::String)
    data_keys = keys(dct_data)
    if ~("color" in data_keys)
        push!(dct_data, "color" => "lightgray")
    end
    if ~("path" in data_keys)
        @warn "$name has no path, skipping"
        return(nothing)::Nothing
    end
    pages = Vector{Component{<:Any}}()
    path::String = path * "/modules/" * dct_data["path"]
    @info "|- - - $path"
    pages = [begin
        pagen = split(n, "_")[2]
        # (cut off .md)
        pagen = pagen[1:length(pagen) - 3]
        rawsrc::String = replace(read(path * "/" * n, String), "\"" => "\\|", "<" => "|\\", ">" => "||\\")
        newmd = tmd(replace(pagen, " " => "-"), rawsrc)
        newmd[:text] = replace(newmd[:text], "\\|" => "\"", "|\\" => "<", "||\\" => ">", "&#33;" => "!", "â€\"" => "--", "&#61;" => "=", 
        "&#39;" => "'")
        newmd
    end for n in readdir(path)]
    DocModule(name, dct_data["color"], pages, path)
end
