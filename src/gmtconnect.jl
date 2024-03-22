"""
	gmtconnect(cmd0::String="", arg1=nothing, kwargs...)

Connect individual lines whose end points match within tolerance

See full GMT (not the `GMT.jl` one) docs at [`gmtconnect`]($(GMTdoc)gmtconnect.html)

Parameters
----------

- **C** | **closed** :: [Type => Str | []]        `Arg = [closed]`

    Write all the closed polygons to closed [gmtgmtconnect_closed.txt] and return all other
    segments as they are. No gmtconnection takes place.
- **D** | **dump** :: [Type => Str | []]   `Arg = [template]`

    For multiple segment data, dump each segment to a separate output file
- **L** | **links** | **linkfile** :: [Type => Str | []]      `Arg = [linkfile]`

    Writes the link information to the specified file [gmtgmtconnect_link.txt].
- **Q** | **list** | **listfile** :: [Type => Str | []]      `Arg =  [listfile]`

    Used with **D** to write a list file with the names of the individual output files.
- **T** | **tolerance** :: [Type => Str | List]    `Arg = [cutoff[unit][/nn_dist]]`

    Specifies the separation tolerance in the data coordinate units [0]; append distance unit.
    If two lines has end-points that are closer than this cutoff they will be joined.
- $(opt_V)
- $(opt_write)
- $(opt_append)
- $(opt_b)
- $(opt_d)
- $(opt_e)
- $(_opt_f)
- $(opt_g)
- $(_opt_h)
- $(_opt_i)
- $(opt_o)
- $(opt_swap_xy)
"""
function gmtconnect(cmd0::String="", arg1=nothing, arg2=nothing; kwargs...)

	d = init_module(false, kwargs...)[1]		# Also checks if the user wants ONLY the HELP mode
	cmd, = parse_common_opts(d, "", [:V_params :b :d :e :f :g :h :i :o :yx])
	cmd  = parse_these_opts(cmd, d, [[:C :closed], [:D :dump], [:L :links :linkfile], [:Q :list :listfile], [:T :tolerance]])

	common_grd(d, cmd0, cmd, "gmtconnect ", arg1)		# Finish build cmd and run it
end

# ---------------------------------------------------------------------------------------------------
gmtconnect(arg1, arg2=nothing; kw...) = gmtconnect("", arg1, arg2; kw...)