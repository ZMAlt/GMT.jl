function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    precompile(Tuple{typeof(Base.Printf.ini_dec),Base.GenericIOBuffer{Array{UInt8,1}},Float64,Int64,String,Int64,Int64,Char,Array{UInt8,1}})
    precompile(Tuple{typeof(Base.__cat),Array{Any,2},Tuple{Int64,Int64},Tuple{Bool,Bool},String,Vararg{Any,N} where N})
    precompile(Tuple{typeof(Base.__cat),Array{Float64,1},Tuple{Int64},Tuple{Bool},Array{Float64,1},Vararg{Any,N} where N})
    precompile(Tuple{typeof(Base.diff_names),NTuple{5,Symbol},Tuple{Symbol}})
    precompile(Tuple{typeof(Base.merge_names),NTuple{5,Symbol},Tuple{Symbol}})
    precompile(Tuple{typeof(Base.merge_types),NTuple{4,Symbol},Type{NamedTuple{(:clip, :first),Tuple{Nothing,Bool}}},Type{NamedTuple{(:W, :Vd),Tuple{Float64,Int64}}}})
    precompile(Tuple{typeof(Base.merge_types),NTuple{4,Symbol},Type{NamedTuple{(:first,),Tuple{Bool}}},Type{NamedTuple{(:F, :D, :par),Tuple{String,String,Tuple{Symbol,Int64}}}}})
    precompile(Tuple{typeof(Base.merge_types),NTuple{4,Symbol},Type{NamedTuple{(:first,),Tuple{Bool}}},Type{NamedTuple{(:pos, :B, :Vd),Tuple{NamedTuple{(:anchor,),Tuple{String}},String,Int64}}}})
    precompile(Tuple{typeof(Base.merge_types),Tuple{Symbol,Symbol},Type{NamedTuple{(:clip, :first),Tuple{Nothing,Bool}}},Type{NamedTuple{(),Tuple{}}}})
    precompile(Tuple{typeof(Base.merge_types),Tuple{Symbol,Symbol},Type{NamedTuple{(:first, :show),Tuple{Bool,Bool}}},Type{NamedTuple{(:show,),Tuple{Bool}}}})
    precompile(Tuple{typeof(Base.merge_types),Tuple{Symbol,Symbol},Type{NamedTuple{(:first,),Tuple{Bool}}},Type{NamedTuple{(:show,),Tuple{Bool}}}})
    precompile(Tuple{typeof(Base.merge_types),Tuple{Symbol},Type{NamedTuple{(:first,),Tuple{Bool}}},Type{NamedTuple{(),Tuple{}}}})
    precompile(Tuple{typeof(copyto!),Array{Float64,1},Tuple{Float64,Int64,Int64}})
    precompile(Tuple{typeof(haskey),Dict{Symbol,Any},String})
    precompile(Tuple{typeof(map),Type,NTuple{160,Char}})
    precompile(Tuple{typeof(map),Type,NTuple{320,Char}})
    precompile(Tuple{typeof(map),Type,NTuple{80,Char}})
    precompile(Tuple{typeof(merge),NamedTuple{(:first, :show),Tuple{Bool,Bool}},Base.Iterators.Pairs{Symbol,Bool,Tuple{Symbol},NamedTuple{(:show,),Tuple{Bool}}}})


    precompile(Tuple{Core.kwftype(typeof(GMT.grdimage)),NamedTuple{(:first, :show),Tuple{Bool,Bool}},typeof(grdimage),String,GMT.GMTgrid})
    precompile(Tuple{Core.kwftype(typeof(GMT.imshow)),NamedTuple{(:show,),Tuple{Bool}},typeof(imshow),String})
    precompile(Tuple{typeof(GMT.GMTJL_Set_Object),Ptr{Nothing},GMT.GMT_RESOURCE,GMT.GMTcpt})
    precompile(Tuple{typeof(GMT.GMTJL_Set_Object),Ptr{Nothing},GMT.GMT_RESOURCE,GMT.GMTgrid})
    precompile(Tuple{typeof(GMT.add_opt),String,String,Dict{Symbol,Any},Array{Any,2}})
    precompile(Tuple{typeof(GMT.add_opt_cpt),Dict{Symbol,Any},String,Array{Symbol,2},Char,Int64,Array{Float64,2}})
    precompile(Tuple{typeof(GMT.common_shade),Dict{Symbol,Any},String,GMT.GMTgrid,GMT.GMTcpt,Nothing,Nothing,String})
    precompile(Tuple{typeof(GMT.finish_PS_module),Dict{Symbol,Any},String,String,Bool,Bool,Bool,Array{Float64,2},Vararg{Any,N} where N})
    precompile(Tuple{typeof(GMT.finish_PS_module),Dict{Symbol,Any},String,String,Bool,Bool,Bool,GMT.GMTgrid,Vararg{Any,N} where N})
    precompile(Tuple{typeof(GMT.get_cpt_set_R),Dict{Symbol,Any},String,String,String,Int64,GMT.GMTgrid,Nothing,Nothing,String})
    precompile(Tuple{typeof(GMT.get_marker_name),Dict{Symbol,Any},Array{Symbol,2},Bool,Bool,Array{Float64,2}})
    precompile(Tuple{typeof(GMT.make_color_column),Dict{Symbol,Any},String,String,Int64,Int64,Int64,Bool,Bool,Array{Float64,2},Nothing})
    precompile(Tuple{typeof(GMT.put_in_legend_bag),Dict{Symbol,Any},String,Array{Float64,2}})
    precompile(Tuple{typeof(GMT.round_wesn),Array{Float64,2}})
    precompile(Tuple{typeof(convert),Type{Ptr{GMT.GMT_MATRIX_v6}},Ptr{Nothing}})
    precompile(Tuple{typeof(plot),Array{Float64,1},Array{Float64,1}})
    precompile(Tuple{typeof(setproperty!),GMT.GMT_GRID_HEADER_v6,Symbol,NTuple{320,UInt8}})
    precompile(Tuple{typeof(setproperty!),GMT.GMT_GRID_HEADER_v6,Symbol,NTuple{80,UInt8}})
end
