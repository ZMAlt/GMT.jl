"""
    pscoast(cmd0::String=""; fmt="", clip=[], K=false, O=false, first=true, kwargs...)

Plot continents, shorelines, rivers, and borders on maps.
Plots grayshaded, colored, or textured land-masses [or water-masses] on
maps and [optionally] draws coastlines, rivers, and political
boundaries. A map projection must be supplied.

Full option list at http://gmt.soest.hawaii.edu/doc/latest/pscoast.html

Parameters
----------

- $(GMT.opt_J)
- $(GMT.opt_R)
- **A** : **area** : -- Str or Number --
    Features with an area smaller than min_area in km^2 or of
    hierarchical level that is lower than min_level or higher than
    max_level will not be plotted.
    [`-A`](http://gmt.soest.hawaii.edu/doc/latest/pscoast.html#a)
- $(GMT.opt_B)
- **C** : **river_fill** : -- Str --
    Set the shade, color, or pattern for lakes and river-lakes.
    [`-C`](http://gmt.soest.hawaii.edu/doc/latest/pscoast.html#c)
- **D** : **res** : **resolution** : -- Str --
    Selects the resolution of the data set to use ((f)ull, (h)igh, (i)ntermediate, (l)ow, and (c)rude).
    [`-D`](http://gmt.soest.hawaii.edu/doc/latest/pscoast.html#d)
- **E** : **ECW** : -- Str --  Tuple(Str, Str); Tuple("code", (pen)), ex: ("PT",(0.5,"red","--")); Tuple((...),(...),...)
    Select painting or dumping country polygons from the Digital Chart of the World
    [`-E`](http://gmt.soest.hawaii.edu/doc/latest/pscoast.html#e)
- **F** : **box** : -- Str --
    Draws a rectangular border around the map scale or rose.
    [`-F`](http://gmt.soest.hawaii.edu/doc/latest/pscoast.html#f)
- **G** : **land** : -- Str --
    Select filling or clipping of “dry” areas.
    [`-G`](http://gmt.soest.hawaii.edu/doc/latest/pscoast.html#g)
- **I** : **rivers** : -- Str --
    Draw rivers. Specify the type of rivers and [optionally] append pen attributes.
    [`-I`](http://gmt.soest.hawaii.edu/doc/latest/pscoast.html#i)
- **L** : **map_scale** : -- Str --
    Dtraw a map scale.
- **M** : **dump** : -- Str --
    Dumps a single multisegment ASCII output. No plotting occurs.
    [`-M`](http://gmt.soest.hawaii.edu/doc/latest/pscoast.html#m)
- **N** : **borders** : -- Str --
    Draw political boundaries. Specify the type of boundary and [optionally] append pen attributes
    [`-N`](http://gmt.soest.hawaii.edu/doc/latest/pscoast.html#n)
- $(GMT.opt_P)
- **S** : **water** : -- Str --
    Select filling or clipping of “wet” areas.
    [`-S`](http://gmt.soest.hawaii.edu/doc/latest/pscoast.html#s)
- **Td** : **rose`** : -- Str --
    Draws a map directional rose on the map at the location defined by the reference and anchor points.
    [`-Td`](http://gmt.soest.hawaii.edu/doc/latest/pscoast.html#t)
- **Tm** : **compass** : -- Str --
    Draws a map magnetic rose on the map at the location defined by the reference and anchor points.
    [`-Tm`](http://gmt.soest.hawaii.edu/doc/latest/pscoast.html#t)
- $(GMT.opt_U)
- $(GMT.opt_V)
- **W** : **shore** : -- Str --
    Draw shorelines [Default is no shorelines]. Append pen attributes.
    [`-W`](http://gmt.soest.hawaii.edu/doc/latest/pscoast.html#w)
- $(GMT.opt_X)
- $(GMT.opt_Y)
- $(GMT.opt_bo)
- $(GMT.opt_p)
- $(GMT.opt_t)
"""
# ---------------------------------------------------------------------------------------------------
function pscoast(cmd0::String=""; fmt="", clip=[], K=false, O=false, first=true, kwargs...)

	if (length(kwargs) == 0)		# Good, speed mode
		return gmt("pscoast " * cmd0)
	end

	output = fmt
	if (!isa(output, String))
		error("Output format or name must be a String")
	else
		output, opt_T, fname_ext = fname_out(output)		# OUTPUT may have been an extension only
	end

	d = KW(kwargs)
	cmd = ""
	maybe_more = false			# If latter set to true, search for lc & lc pen settings
	cmd, opt_R = parse_R(cmd, d)
	cmd, opt_J = parse_J(cmd, d)
	cmd, opt_B = parse_B(cmd, d)
	cmd = parse_U(cmd, d)
	cmd = parse_V(cmd, d)
	cmd = parse_X(cmd, d)
	cmd = parse_Y(cmd, d)
	cmd = parse_p(cmd, d)
	cmd = parse_t(cmd, d)
	cmd = parse_bo(cmd, d)

	if (first)  K = true;	O = false
	else        K = true;	O = true;	cmd = replace(cmd, opt_B, "");	opt_B = ""
	end

	if (!isempty(clip))
		if (clip == "land")       cmd = cmd * " -Gc"
		elseif (clip == "water")  cmd = cmd * " -Sc"
		elseif (clip == "end")    cmd = cmd * " -Q"
		else
			warn("The 'clip' argument can only be \"land\", \"water\" or \"end\". Ignoring it.")
		end
	end

	for symb in [:I :rivers]
		if (haskey(d, symb))
			if (isa(d[symb], Number))      cmd = @sprintf("%s -I%d", cmd, d[symb])
			elseif (isa(d[symb], String))  cmd = cmd * " -I" * d[symb]
			elseif (isa(d[symb], Tuple))   cmd = cmd * " -I" * parse_arg_and_pen(d[symb])
			end
			break
		end
	end

	for symb in [:N :borders]
		if (haskey(d, symb))
			if (isa(d[symb], Number))      cmd = @sprintf("%s -N%d", cmd, d[symb])
			elseif (isa(d[symb], String))  cmd = cmd * " -N" * d[symb]
			elseif (isa(d[symb], Tuple))   cmd = cmd * " -N" * parse_arg_and_pen(d[symb])
			end
			break
		end
	end

	for symb in [:W :shore :shore1 :shore2 :shore3 :shore4]
		if (haskey(d, symb))
			if (symb == :shore || symb == :W) lev = " -W"
			elseif (symb == :shore1)          lev = " -W1/"
			elseif (symb == :shore2)          lev = " -W2/" 
			elseif (symb == :shore3)          lev = " -W3/" 
			elseif (symb == :shore4)          lev = " -W4/" 
			end
			if (isa(d[symb], Tuple))  cmd = cmd * lev * parse_pen(d[symb])
			else                      cmd = cmd * lev * arg2str(d[symb]);		maybe_more = true
			end
		end
	end

	if (maybe_more)				# Search for color and style line settings
		lc = parse_pen_color(d)
		if (!isempty(lc))
			cmd = cmd * "," * lc
			ls = parse_pen_style(d)
			if (!isempty(ls))		cmd = cmd * "," * ls	end
		end
		maybe_more = false		# and because we can use this only once, deactivate it
	end

	cmd = add_opt(cmd, 'A', d, [:A :area])
	cmd = add_opt_s(cmd, 'C', d, [:C :river_fill])
	cmd = add_opt_s(cmd, 'D', d, [:D :res :resolution])

	for sb in [:E :DCW]
		if (haskey(d, sb))
			if (isa(d[sb], String))
				cmd = cmd * " -E" * d[sb]							# Simple case, ex E="PT,+gblue"
			elseif (isa(d[sb], Tuple))
				if (length(d[sb]) == 2 && isa(d[sb][1], Char) && isa(d[sb][2], Char))			# ex E=("PT","+p0.5")
					cmd = string(cmd, " -E", d[sb][1], ",", d[sb][2])
				elseif (length(d[sb]) == 2 && isa(d[sb][1], Char) && isa(d[sb][2], Tuple))		# ex E=("PT",(0.5,"red","--"))
					cmd = string(cmd, " -E", d[sb][1], ",+p", parse_pen(d[sb][2]))
				elseif (length(d[sb]) >= 2 && isa(d[sb][1], Tuple) && isa(d[sb][end], Tuple)) 	# ex E=((),(),...,())
					for k = 1:length(d[sb])
						if (isa(d[sb][k][2], Char))  cmd = string(cmd, " -E", d[sb][k][1], ",", d[sb][k][2])
						else                         cmd = string(cmd, " -E", d[sb][k][1], ",+p", parse_pen(d[sb][k][2]))
						end
					end
				end
			else
				error("Arguments of E can only be a String or a Tuple (or Tuple of Tuples")
			end
			break
		end
	end

	cmd = add_opt_s(cmd, 'F', d, [:F :box])
	cmd = add_opt(cmd, 'G', d, [:G :land])
	cmd = add_opt_s(cmd, 'L', d, [:L :map_scale])
	cmd = add_opt(cmd, 'M', d, [:M :dump])
	cmd = add_opt(cmd, 'S', d, [:S :water])
	cmd = add_opt_s(cmd, "Td", d, [:Td :rose])
	cmd = add_opt_s(cmd, "Tm", d, [:Td :compass])

	cmd = finish_PS(d, cmd0, cmd, output, K, O)

	if (haskey(d, :ps)) PS = true			# To know if returning PS to the REPL was requested
	else                PS = false
	end

	(haskey(d, :Vd)) && println(@sprintf("\tpscoast %s", cmd))

	P = nothing
	if (PS) P = gmt("pscoast " * cmd)
	else        gmt("pscoast " * cmd)
	end
	if (haskey(d, :show)) 					# Display Fig in default viewer
		showfig(output, fname_ext, opt_T, K)
	elseif (haskey(d, :savefig))
		showfig(output, fname_ext, opt_T, K, d[:savefig])
	end
	return P
end

# ---------------------------------------------------------------------------------------------------
pscoast!(cmd0::String=""; fmt="", clip=[], K=false, O=false, first=false, kwargs...) =
	pscoast!(cmd0; fmt="", clip=[], K=true, O=true, first=false, kwargs...)