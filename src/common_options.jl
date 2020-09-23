# Parse the common options that all GMT modules share, plus some others functions of also common usage

const KW = Dict{Symbol,Any}
nt2dict(nt::NamedTuple) = nt2dict(; nt...)
nt2dict(; kw...) = Dict(kw)
# Need the Symbol.() below in oder to work from PyCall
# A darker an probably more efficient way is: ((; kw...) -> kw.data)(; d...) but breaks in PyCall
dict2nt(d::Dict) = NamedTuple{Tuple(Symbol.(keys(d)))}(values(d))

function find_in_dict(d::Dict, symbs, del=true)
	# See if D contains any of the symbols in SYMBS. If yes, return corresponding value
	for symb in symbs
		if (haskey(d, symb))
			val = d[symb]
			if (del) delete!(d, symb) end
			return val, symb
		end
	end
	return nothing, 0
end

function del_from_dict(d::Dict, symbs::Array{Array{Symbol}})
	# Delete SYMBS from the D dict where SYMBS is an array of array os symbols
	# Example:  del_from_dict(d, [[:a :b], [:c]])
	for symb in symbs
		del_from_dict(d, symb)
	end
end

function del_from_dict(d::Dict, symbs::Array{Symbol})
	# Delete SYMBS from the D dict where symbs is an array of symbols and elements are aliases
	for alias in symbs
		if (haskey(d, alias))
			delete!(d, alias)
			return
		end
	end
end

function parse_R(cmd::String, d::Dict, O=false, del=false)
	# Build the option -R string. Make it simply -R if overlay mode (-O) and no new -R is fished here
	opt_R = Array{String,1}(undef,1)
	opt_R = [""]
	val, symb = find_in_dict(d, [:R :region :limits])
	if (val !== nothing)
		opt_R[1] = build_opt_R(val)
		if (del) delete!(d, symb) end
	elseif (IamModern[1])
		return cmd, ""
	end

	if (opt_R[1] == "")		# See if we got the region as tuples of xlim, ylim [zlim]
		R = "";		c = 0
		if (haskey(d, :xlim) && isa(d[:xlim], Tuple) && length(d[:xlim]) == 2)
			R = @sprintf(" -R%.15g/%.15g", d[:xlim][1], d[:xlim][2])
			c += 2
			if (haskey(d, :ylim) && isa(d[:ylim], Tuple) && length(d[:ylim]) == 2)
				R = @sprintf("%s/%.15g/%.15g", R, d[:ylim][1], d[:ylim][2])
				c += 2
				if (haskey(d, :zlim) && isa(d[:zlim], Tuple) && length(d[:zlim]) == 2)
					R = @sprintf("%s/%.15g/%.15g", R, d[:zlim][1], d[:zlim][2])
					del_from_dict(d, [:zlim])
				end
				del_from_dict(d, [:ylim])
			end
			del_from_dict(d, [:xlim])
		end
		if (!isempty(R) && c == 4)  opt_R[1] = R  end
	end
	if (O && isempty(opt_R[1]))  opt_R[1] = " -R"  end
	cmd = cmd * opt_R[1]
	return cmd, opt_R[1]
end

function build_opt_R(Val)		# Generic function that deals with all but NamedTuple args
	if (isa(Val, String) || isa(Val, Symbol))
		r = string(Val)
		if     (r == "global")     return " -Rd"
		elseif (r == "global360")  return " -Rg"
		elseif (r == "same")       return " -R"
		else                       return " -R" * r
		end
	elseif ((isa(Val, Array{<:Number}) || isa(Val, Tuple)) && (length(Val) == 4 || length(Val) == 6))
		out = arg2str(Val)
		return " -R" * rstrip(out, '/')		# Remove last '/'
	elseif (isa(Val, GMTgrid) || isa(Val, GMTimage))
		return @sprintf(" -R%.15g/%.15g/%.15g/%.15g", Val.range[1], Val.range[2], Val.range[3], Val.range[4])
	end
	return ""
end

function build_opt_R(arg::NamedTuple)
	# Option -R can also be diabolicly complicated. Try to addres it. Stil misses the Time part.
	BB = Array{String,1}(undef,1)
	BB = [""]
	d = nt2dict(arg)					# Convert to Dict
	if ((val = find_in_dict(d, [:bb :limits :region])[1]) !== nothing)
		if ((isa(val, Array{<:Number}) || isa(val, Tuple)) && (length(val) == 4 || length(val) == 6))
			if (haskey(d, :diag))		# The diagonal case
				BB[1] = @sprintf("%.15g/%.15g/%.15g/%.15g+r", val[1], val[3], val[2], val[4])
			else
				BB[1] = join([@sprintf("%.15g/",x) for x in val])
				BB[1] = rstrip(BB[1], '/')		# and remove last '/'
			end
		elseif (isa(val, String) || isa(val, Symbol))
			t = string(val)
			if     (t == "global")     BB[1] = "-180/180/-90/90"
			elseif (t == "global360")  BB[1] = "0/360/-90/90"
			else                       BB[1] = string(val) 			# Whatever good stuff or shit it may contain
			end
		end
	elseif ((val = find_in_dict(d, [:bb_diag :limits_diag :region_diag :LLUR])[1]) !== nothing)	# Alternative way of saying "+r"
		BB[1] = @sprintf("%.15g/%.15g/%.15g/%.15g+r", val[1], val[3], val[2], val[4])
	elseif ((val = find_in_dict(d, [:continent :cont])[1]) !== nothing)
		val = uppercase(string(val))
		if     (startswith(val, "AF"))  BB[1] = "=AF"
		elseif (startswith(val, "AN"))  BB[1] = "=AN"
		elseif (startswith(val, "AS"))  BB[1] = "=AS"
		elseif (startswith(val, "EU"))  BB[1] = "=EU"
		elseif (startswith(val, "OC"))  BB[1] = "=OC"
		elseif (val[1] == 'N')  BB[1] = "=NA"
		elseif (val[1] == 'S')  BB[1] = "=SA"
		else   error("Unknown continent name")
		end
	elseif ((val = find_in_dict(d, [:ISO :iso])[1]) !== nothing)
		if (isa(val, String))  BB[1] = val
		else                   error("argument to the ISO key must be a string with country codes")
		end
	end

	if ((val = find_in_dict(d, [:adjust :pad :extend :expand])[1]) !== nothing)
		if (isa(val, String) || isa(val, Number))  t = string(val)
		elseif (isa(val, Array{<:Number}) || isa(val, Tuple))
			t = join([@sprintf("%.15g/",x) for x in val])
			t = rstrip(t, '/')		# and remove last '/'
		else
			error("Increments for limits must be a String, a Number, Array or Tuple")
		end
		if (haskey(d, :adjust))  BB[1] *= "+r" * t
		else                     BB[1] *= "+R" * t
		end
	end

	if (haskey(d, :unit))  BB[1] *= "+u" * string(d[:unit])[1]  end	# (e.g., -R-200/200/-300/300+uk)

	if (BB[1] == "")
		error("No, no, no. Nothing useful in the region named tuple arguments")
	else
		return " -R" * BB[1]
	end
end

# ---------------------------------------------------------------------------------------------------
function opt_R2num(opt_R::String)
	# Take a -R option string and convert it to numeric
	if (opt_R == "")  return nothing  end
	if (endswith(opt_R, "Rg"))  return [0.0 360. -90. 90.]  end
	if (endswith(opt_R, "Rd"))  return [-180.0 180. -90. 90.]  end
	rs = split(opt_R, '/')
	limits = zeros(1,length(rs))
	fst = 0
	if ((ind = findfirst("R", rs[1])) !== nothing)  fst = ind[1]  end
	limits[1] = parse(Float64, rs[1][fst+1:end])
	for k = 2:length(rs)
		limits[k] = parse(Float64, rs[k])
	end
	return limits
end

# ---------------------------------------------------------------------------------------------------
function parse_JZ(cmd::String, d::Dict, del=true)
	opt_J = ""
	val, symb = find_in_dict(d, [:JZ :Jz :zscale :zsize], del)
	if (val !== nothing)
		if (symb == :JZ || symb == :zsize)  opt_J = " -JZ" * arg2str(val)
		else                                opt_J = " -Jz" * arg2str(val)
		end
		cmd *= opt_J
		#if (del) delete!(d, symb) end
	end
	return cmd, opt_J
end

# ---------------------------------------------------------------------------------------------------
function parse_J(cmd::String, d::Dict, default="", map=true, O=false, del=true)
	# Build the option -J string. Make it simply -J if overlay mode (-O) and no new -J is fished here
	# Default to 12c if no size is provided.
	# If MAP == false, do not try to append a fig size
	opt_J = Array{String,1}(undef,1)
	opt_J = [""];		mnemo = false
	if ((val = find_in_dict(d, [:J :proj :projection], del)[1]) !== nothing)
		if (isa(val, Dict))  val = dict2nt(val)  end
		opt_J[1], mnemo = build_opt_J(val)
	elseif (IamModern[1] && ((val = find_in_dict(d, [:figscale :fig_scale :scale :figsize :fig_size], del)[1]) === nothing))
		# Subplots do not rely is the classic default mechanism
		return cmd, ""
	end
	if (!map && opt_J[1] != "")
		return cmd * opt_J[1], opt_J[1]
	end

	(O && opt_J[1] == "") && (opt_J[1] = " -J")

	if (!O)
		(opt_J[1] == "") && (opt_J[1] = " -JX")
		# If only the projection but no size, try to get it from the kwargs.
		if ((s = helper_append_figsize(d, opt_J[1], O)) != "")		# Takes care of both fig scales and fig sizes
			opt_J[1] = s
		elseif (default != "" && opt_J[1] == " -JX")
			opt_J[1] = IamSubplot[1] ? " -JX?" : default  			# -JX was a working default
		elseif (occursin("+width=", opt_J[1]))		# OK, a proj4 string, don't touch it. Size already in.
		elseif (occursin("+proj", opt_J[1]))		# A proj4 string but no size info. Use default size
			opt_J[1] *= "+width=" * split(def_fig_size, '/')[1]
		elseif (mnemo)							# Proj name was obtained from a name mnemonic and no size. So use default
			opt_J[1] = append_figsize(d, opt_J[1])
		elseif (!isnumeric(opt_J[1][end]) && (length(opt_J[1]) < 6 || (isletter(opt_J[1][5]) && !isnumeric(opt_J[1][6]))) )
			if ((val = find_in_dict(d, [:aspect])[1]) !== nothing)  val = string(val)  end
			if (!IamSubplot[1])
				if (val == "equal")  opt_J[1] *= split(def_fig_size, '/')[1] * "/0"
				else                 opt_J[1] *= def_fig_size
				end
			elseif (!occursin("?", opt_J[1]))	# If we dont have one ? for size/scale already
				opt_J[1] *= "/?"
			end
		#elseif (length(opt_J[1]) == 4 || (length(opt_J[1]) >= 5 && isletter(opt_J[1][5])))
			#if (length(opt_J[1][1]) < 6 || !isnumeric(opt_J[1][6]))
				#opt_J[1] *= def_fig_size
			#end
		end
	else										# For when a new size is entered in a middle of a script
		if ((s = helper_append_figsize(d, opt_J[1], O)) != "")  opt_J[1] = s  end
	end
	cmd *= opt_J[1]
	return cmd, opt_J[1]
end

function helper_append_figsize(d::Dict, opt_J::String, O::Bool)::String
	val_, symb = find_in_dict(d, [:figscale :fig_scale :scale :figsize :fig_size])
	if (val_ === nothing)  return ""  end
	val::String = arg2str(val_)
	if (occursin("scale", arg2str(symb)))		# We have a fig SCALE request
		if     (IamSubplot[1] && val == "auto")       val = "?"
		elseif (IamSubplot[1] && val == "auto,auto")  val = "?/?"
		end
		if (opt_J == " -JX")
			val = check_axesswap(d, val)
			isletter(val[1]) ? opt_J = " -J" * val : opt_J = " -Jx" * val		# FRAGILE
		elseif (O && opt_J == " -J")  error("In Overlay mode you cannot change a fig scale and NOT repeat the projection")
		else                          opt_J = append_figsize(d, opt_J, val, true)
		end
	else										# A fig SIZE request
		(haskey(d, :units)) && (val *= d[:units][1])
		if (occursin("+proj", opt_J)) opt_J *= "+width=" * val
		else                          opt_J = append_figsize(d, opt_J, val)
		end
	end
	return opt_J
end

function append_figsize(d::Dict, opt_J::String, width="", scale=false)
	# Appending either a fig width or fig scale depending on what projection.
	# Sometimes we need to separate with a '/' others not. If WIDTH == "" we
	# use the DEF_FIG_SIZE, otherwise use WIDTH that can be a size or a scale.
	if (width == "")
		width = (IamSubplot[1]) ? "?" : split(def_fig_size, '/')[1]		# In subplot "?" is auto width
	elseif (IamSubplot[1] && (width == "auto" || width == "auto,auto"))	# In subplot one can say figsize="auto" or figsize="auto,auto"
		width = (width == "auto") ? "?" : "?/?"
	elseif ( ((val = find_in_dict(d, [:aspect], false)[1]) !== nothing) && (val == "equal" || val == :equal))
		del_from_dict(d, [:aspect])		# Delete this kwarg but only after knowing its val
		if (occursin("/", width))
			@warn("Ignoring the axis 'equal' request because figsize with Width and Height already provided.")
		else
			width *= "/0"
		end
	end

	slash = "";		de = ""
	if (opt_J[end] == 'd')  opt_J = opt_J[1:end-1];		de = "d"  end
	if (isnumeric(opt_J[end]) && ~startswith(opt_J, " -JXp"))    slash = "/";#opt_J *= "/" * width
	else
		if (occursin("Cyl_", opt_J) || occursin("Poly", opt_J))  slash = "/";#opt_J *= "/" * width
		elseif (startswith(opt_J, " -JU") && length(opt_J) > 4)  slash = "/";#opt_J *= "/" * width
		else								# Must parse for logx, logy, loglog, etc
			if (startswith(opt_J, " -JXl") || startswith(opt_J, " -JXp") ||
				startswith(opt_J, " -JXT") || startswith(opt_J, " -JXt"))
				ax = opt_J[6];	flag = opt_J[5];
				if (flag == 'p' && length(opt_J) > 6)  flag *= opt_J[7:end]  end	# Case p<power>
				opt_J = opt_J[1:4]			# Trim the consumed options
				w_h = split(width,"/")
				if (length(w_h) == 2)		# Must find which (or both) axis is scaling be applyied
					(ax == 'x') ? w_h[1] *= flag : ((ax == 'y') ? w_h[2] *= flag : w_h .*= flag)
					width = w_h[1] * '/' * w_h[2]
				elseif (ax == 'y')  error("Can't select Y scaling and provide X dimension only")
				else
					width *= flag
				end
			end
		end
	end
	width = check_axesswap(d, width)
	opt_J *= slash * width * de
	if (scale)  opt_J = opt_J[1:3] * lowercase(opt_J[4]) * opt_J[5:end]  end 		# Turn " -JX" to " -Jx"
	return opt_J
end

function check_axesswap(d::Dict, width::AbstractString)
	# Deal with the case that we want to invert the axis sense
	# axesswap(x=true, y=true) OR  axesswap("x", :y) OR axesswap(:xy)
	if (width == "" || (val = find_in_dict(d, [:inverse_axes :axesswap :axes_swap])[1]) === nothing)
		return width
	end

	swap_x = false;		swap_y = false;
	if (isa(val, Dict))  val = dict2nt(val)  end
	if (isa(val, NamedTuple))
		for k in keys(val)
			if     (k == :x)  swap_x = true
			elseif (k == :y)  swap_y = true
			elseif (k == :xy) swap_x = true;  swap_y = true
			end
		end
	elseif (isa(val, Tuple))
		for k in val
			if     (string(k) == "x")  swap_x = true
			elseif (string(k) == "y")  swap_y = true
			elseif (string(k) == "xy") swap_x = true;  swap_y = true
			end
		end
	elseif (isa(val, String) || isa(val, Symbol))
		if     (string(val) == "x")  swap_x = true
		elseif (string(val) == "y")  swap_y = true
		elseif (string(val) == "xy") swap_x = true;  swap_y = true
		end
	end

	if (occursin("/", width))
		sizes = split(width,"/")
		if (swap_x) sizes[1] = "-" * sizes[1]  end
		if (swap_y) sizes[2] = "-" * sizes[2]  end
		width = sizes[1] * "/" * sizes[2]
	else
		width = "-" * width
	end
	if (occursin("?-", width))  width = replace(width, "?-" => "-?")  end 	# It may, from subplots
	return width
end

function build_opt_J(Val)
	out = Array{String,1}(undef,1)
	out = [""];		mnemo = false
	if (isa(Val, String) || isa(Val, Symbol))
		prj, mnemo = parse_proj(string(Val))
		out[1] = " -J" * prj
	elseif (isa(Val, NamedTuple))
		prj, mnemo = parse_proj(Val)
		out[1] = " -J" * prj
	elseif (isa(Val, Number))
		if (!(typeof(Val) <: Int) || Val < 2000)
			error("The only valid case to provide a number to the 'proj' option is when that number is an EPSG code, but this (" * string(Val) * ") is clearly an invalid EPSG")
		end
		out[1] = string(" -J", string(Val))
	elseif (isempty(Val))
		out[1] = " -J"
	end
	return out[1], mnemo
end

function parse_proj(p::String)
	# See "p" is a string with a projection name. If yes, convert it into the corresponding -J syntax
	if (p == "")  return p,false  end
	if (p[1] == '+' || startswith(p, "epsg") || startswith(p, "EPSG") || occursin('/', p) || length(p) < 3)
		p = replace(p, " " => "")		# Remove the spaces from proj4 strings
		return p,false
	end
	out = Array{String,1}(undef,1)
	out = [""];
	mnemo = true			# True when the projection name used one of the below mnemonics
	s = lowercase(p)
	if     (s == "aea"   || s == "albers")                 out[1] = "B0/0"
	elseif (s == "cea"   || s == "cylindricalequalarea")   out[1] = "Y0/0"
	elseif (s == "laea"  || s == "lambertazimuthal")       out[1] = "A0/0"
	elseif (s == "lcc"   || s == "lambertconic")           out[1] = "L0/0"
	elseif (s == "aeqd"  || s == "azimuthalequidistant")   out[1] = "E0/0"
	elseif (s == "eqdc"  || s == "conicequidistant")       out[1] = "D0/90"
	elseif (s == "tmerc" || s == "transversemercator")     out[1] = "T0"
	elseif (s == "eqc"   || startswith(s, "plat") || startswith(s, "equidist") || startswith(s, "equirect"))  out[1] = "Q"
	elseif (s == "eck4"  || s == "eckertiv")               out[1] = "Kf"
	elseif (s == "eck6"  || s == "eckertvi")               out[1] = "Ks"
	elseif (s == "omerc" || s == "obliquemerc1")           out[1] = "Oa"
	elseif (s == "omerc2"|| s == "obliquemerc2")           out[1] = "Ob"
	elseif (s == "omercp"|| s == "obliquemerc3")           out[1] = "Oc"
	elseif (startswith(s, "cyl_") || startswith(s, "cylindricalster"))  out[1] = "Cyl_stere"
	elseif (startswith(s, "cass"))   out[1] = "C0/0"
	elseif (startswith(s, "geo"))    out[1] = "Xd"		# Linear geogs
	elseif (startswith(s, "gnom"))   out[1] = "F0/0"
	elseif (startswith(s, "ham"))    out[1] = "H"
	elseif (startswith(s, "lin"))    out[1] = "X"
	elseif (startswith(s, "logx"))   out[1] = "Xlx"
	elseif (startswith(s, "logy"))   out[1] = "Xly"
	elseif (startswith(s, "loglog")) out[1] = "Xll"
	elseif (startswith(s, "powx"))   v = split(s, ',');	length(v) == 2 ? out[1] = "Xpx" * v[2] : out[1] = "Xpx"
	elseif (startswith(s, "powy"))   v = split(s, ',');	length(v) == 2 ? out[1] = "Xpy" * v[2] : out[1] = "Xpy"
	elseif (startswith(s, "Time"))   out[1] = "XTx"
	elseif (startswith(s, "time"))   out[1] = "Xtx"
	elseif (startswith(s, "merc"))   out[1] = "M"
	elseif (startswith(s, "mil"))    out[1] = "J"
	elseif (startswith(s, "mol"))    out[1] = "W"
	elseif (startswith(s, "ortho"))  out[1] = "G0/0"
	elseif (startswith(s, "poly"))   out[1] = "Poly"
	elseif (s == "polar")            out[1] = "P"
	elseif (s == "polar_azim")       out[1] = "Pa"
	elseif (startswith(s, "robin"))  out[1] = "N"
	elseif (startswith(s, "stere"))  out[1] = "S0/90"
	elseif (startswith(s, "sinu"))   out[1] = "I"
	elseif (startswith(s, "utm"))    out[1] = "U" * s[4:end]
	elseif (startswith(s, "vand"))   out[1] = "V"
	elseif (startswith(s, "win"))    out[1] = "R"
	else   out[1] = p;		mnemo = false
	end
	return out[1], mnemo
end

function parse_proj(p::NamedTuple)
	# Take a proj=(name=xxxx, center=[lon lat], parallels=[p1 p2]), where either center or parallels
	# may be absent, but not BOTH, an create a GMT -J syntax string (note: for some projections 'center'
	# maybe a scalar but the validity of that is not checked here).
	d = nt2dict(p)					# Convert to Dict
	if ((val = find_in_dict(d, [:name])[1]) !== nothing)
		prj, mnemo = parse_proj(string(val))
		if (prj != "Cyl_stere" && prj == string(val))
			@warn("Very likely the projection name ($prj) is unknown to me. Expect troubles")
		end
	else
		error("When projection arguments are in a NamedTuple the projection 'name' keyword is madatory.")
	end

	center = ""
	if ((val = find_in_dict(d, [:center])[1]) !== nothing)
		if     (isa(val, String))  center = val
		elseif (isa(val, Number))  center = @sprintf("%.12g", val)
		elseif (isa(val, Array) || isa(val, Tuple) && length(val) == 2)
			if (isa(val, Array))  center = @sprintf("%.12g/%.12g", val[1], val[2])
			else		# Accept also strings in tuple (Needed for movie)
				center  = (isa(val[1], String)) ? val[1] * "/" : @sprintf("%.12g/", val[1])
				center *= (isa(val[2], String)) ? val[2] : @sprintf("%.12g", val[2])
			end
		end
	end

	if (center != "" && (val = find_in_dict(d, [:horizon])[1]) !== nothing)  center = string(center, '/',val)  end

	parallels = ""
	if ((val = find_in_dict(d, [:parallel :parallels])[1]) !== nothing)
		if     (isa(val, String))  parallels = "/" * val
		elseif (isa(val, Number))  parallels = @sprintf("/%.12g", val)
		elseif (isa(val, Array) || isa(val, Tuple) && (length(val) <= 3 || length(val) == 6))
			parallels = join([@sprintf("/%.12g",x) for x in val])
		end
	end

	if     (center == "" && parallels != "")  center = "0/0" * parallels
	elseif (center != "")                     center *= parallels			# even if par == ""
	else   error("When projection is a named tuple you need to specify also 'center' and|or 'parallels'")
	end
	if (startswith(prj, "Cyl"))  prj = prj[1:9] * "/" * center	# The unique Cyl_stere case
	elseif (prj[1] == 'K' || prj[1] == 'O')  prj = prj[1:2] * center	# Eckert || Oblique Merc
	else                                     prj = prj[1]   * center
	end
	return prj, mnemo
end

# ---------------------------------------------------------------------------------------------------
function parse_B(cmd::String, d::Dict, _opt_B::String="", del=true)

	def_fig_axes_  = (IamModern[1]) ? "" : def_fig_axes		# def_fig_axes is a global const
	def_fig_axes3_ = (IamModern[1]) ? "" : def_fig_axes3	# def_fig_axes is a global const

	opt_B = Array{String,1}(undef,1)
	opt_B[1] = _opt_B

	# These four are aliases
	extra_parse = true;
	if ((val = find_in_dict(d, [:B :frame :axis :axes], del)[1]) !== nothing)
		if (isa(val, Dict))  val = dict2nt(val)  end
		if (isa(val, String) || isa(val, Symbol))
			val = string(val)					# In case it was a symbol
			if (val == "none")					# User explicitly said NO AXES
				return cmd, ""
			elseif (val == "noannot" || val == "bare")
				return cmd * " -B0", " -B0"
			elseif (val == "same")				# User explicitly said "Same as previous -B"
				return cmd * " -B", " -B"
			elseif (startswith(val, "auto"))
				if     (occursin("XYZg", val)) val = (GMTver <= 6.1) ? " -Bafg -Bzafg -B+b" : " -Bafg -Bzafg -B+w"
				elseif (occursin("XYZ", val))  val = def_fig_axes3
				elseif (occursin("XYg", val))  val = " -Bafg -BWSen"
				elseif (occursin("XY", val))   val = def_fig_axes
				elseif (occursin("LB", val))   val = " -Baf -BLB"
				elseif (occursin("L",  val))   val = " -Baf -BL"
				elseif (occursin("R",  val))   val = " -Baf -BR"
				elseif (occursin("B",  val))   val = " -Baf -BB"
				elseif (occursin("Xg", val))   val = " -Bafg -BwSen"
				elseif (occursin("X",  val))   val = " -Baf -BwSen"
				elseif (occursin("Yg", val))   val = " -Bafg -BWsen"
				elseif (occursin("Y",  val))   val = " -Baf -BWsen"
				elseif (val == "auto")         val = def_fig_axes		# 2D case
				end
			end
		end
		if (isa(val, NamedTuple)) opt_B[1] = axis(val);	extra_parse = false
		else                      opt_B[1] = string(val)
		end
	end

	# Let the :title and x|y_label be given on main kwarg list. Risky if used with NamedTuples way.
	t = ""		# Use the trick to replace blanks by some utf8 char and undo it in extra_parse
	if (haskey(d, :title))   t *= "+t"   * replace(str_with_blancs(d[:title]), ' '=>'\U00AF');   delete!(d, :title);	end
	if (haskey(d, :xlabel))  t *= " x+l" * replace(str_with_blancs(d[:xlabel]),' '=>'\U00AF');   delete!(d, :xlabel);	end
	if (haskey(d, :ylabel))  t *= " y+l" * replace(str_with_blancs(d[:ylabel]),' '=>'\U00AF');   delete!(d, :ylabel);	end
	if (t != "")
		if (opt_B[1] == "" && (val = find_in_dict(d, [:xaxis :yaxis :zaxis], false)[1] === nothing))
			opt_B[1] = def_fig_axes_
		else
			if !( ((ind = findlast("-B",opt_B[1])) !== nothing || (ind = findlast(" ",opt_B[1])) !== nothing) &&
				  (occursin(r"[WESNwesntlbu+g+o]",opt_B[1][ind[1]:end])) )
				t = " " * t;		# Do not glue, for example, -Bg with :title
			end
		end
		if (val = find_in_dict(d, [:xaxis :yaxis :zaxis :axis2 :xaxis2 :yaxis2], false)[1] === nothing)
			opt_B[1] *= t;
		else
			opt_B[1] = t;
		end
		extra_parse = true
	end

	# These are not and we can have one or all of them. NamedTuples are dealt at the end
	for symb in [:xaxis :yaxis :zaxis :axis2 :xaxis2 :yaxis2]
		if (haskey(d, symb) && !isa(d[symb], NamedTuple))
			opt_B[1] = string(d[symb], " ", opt_B[1])
		end
	end

	if (extra_parse && (opt_B[1] != def_fig_axes && opt_B[1] != def_fig_axes3))
		# This is old code that takes care to break a string in tokens and prefix with a -B to each token
		tok = Vector{String}(undef, 10)
		k = 1;		r = opt_B[1];		found = false
		while (r != "")
			tok[k], r = GMT.strtok(r)
			tok[k] = replace(tok[k], '\U00AF'=>' ')
			if (!occursin("-B", tok[k]))  tok[k] = " -B" * tok[k] 	# Simple case, no quotes to break our heads
			else                          tok[k] = " " * tok[k]
			end
			k = k + 1
		end
		# Rebuild the B option string
		opt_B[1] = ""
		for n = 1:k-1
			opt_B[1] *= tok[n]
		end
	end

	# We can have one or all of them. Deal separatelly here to allow way code to keep working
	this_opt_B = "";
	for symb in [:yaxis2 :xaxis2 :axis2 :zaxis :yaxis :xaxis]
		if (haskey(d, symb) && (isa(d[symb], NamedTuple) || isa(d[symb], Dict)))
			if (isa(d[symb], Dict))  d[symb] = dict2nt(d[symb])  end
			if     (symb == :axis2)   this_opt_B = axis(d[symb], secondary=true);	delete!(d, symb)
			elseif (symb == :xaxis)   this_opt_B = axis(d[symb], x=true) * this_opt_B;	delete!(d, symb)
			elseif (symb == :xaxis2)  this_opt_B = axis(d[symb], x=true, secondary=true) * this_opt_B;	delete!(d, symb)
			elseif (symb == :yaxis)   this_opt_B = axis(d[symb], y=true) * this_opt_B;	delete!(d, symb)
			elseif (symb == :yaxis2)  this_opt_B = axis(d[symb], y=true, secondary=true) * this_opt_B;	delete!(d, symb)
			elseif (symb == :zaxis)   this_opt_B = axis(d[symb], z=true) * this_opt_B;	delete!(d, symb)			end
		end
	end

	if (opt_B[1] != def_fig_axes_ && opt_B[1] != def_fig_axes3_)  opt_B[1] = this_opt_B * opt_B[1]
	elseif (this_opt_B != "")  opt_B[1] = this_opt_B
	end

	return cmd * opt_B[1], opt_B[1]
end

# ---------------------------------------------------------------------------------------------------
function parse_BJR(d::Dict, cmd::String, caller::String, O::Bool, defaultJ="", del=true)
	# Join these three in one function. CALLER is non-empty when module is called by plot()
	cmd, opt_R = parse_R(cmd, d, O, del)
	cmd, opt_J = parse_J(cmd, d, defaultJ, true, O, del)

	def_fig_axes_ = (IamModern[1]) ? "" : def_fig_axes	# def_fig_axes is a global const

	if (caller != "" && occursin("-JX", opt_J))		# e.g. plot() sets 'caller'
		if (occursin("3", caller) || caller == "grdview")
			def_fig_axes3_ = (IamModern[1]) ? "" : def_fig_axes3
			cmd, opt_B = parse_B(cmd, d, (O ? "" : def_fig_axes3_), del)
		else
			cmd, opt_B = parse_B(cmd, d, (O ? "" : def_fig_axes_), del)	# For overlays, default is no axes
		end
	else
		cmd, opt_B = parse_B(cmd, d, (O ? "" : def_fig_axes_), del)
	end
	return cmd, opt_B, opt_J, opt_R
end

# ---------------------------------------------------------------------------------------------------
function parse_F(cmd::String, d::Dict)
	cmd = add_opt(cmd, 'F', d, [:F :box], (clearance="+c", fill=("+g", add_opt_fill), inner="+i",
	                                       pen=("+p", add_opt_pen), rounded="+r", shaded=("+s", arg2str)) )
end

# ---------------------------------------------------------------------------------------------------
function parse_UXY(cmd::String, d::Dict, aliases, opt::Char)
	# Parse the global -U, -X, -Y options. Return CMD same as input if no option OPT in args
	# ALIASES: [:X :x_off :x_offset] (same for Y) or [:U :time_stamp :stamp]
	if ((val = find_in_dict(d, aliases, true)[1]) !== nothing)
		cmd = string(cmd, " -", opt, val)
	end
	return cmd
end

# ---------------------------------------------------------------------------------------------------
function parse_V(cmd::String, d::Dict)
	# Parse the global -V option. Return CMD same as input if no -V option in args
	if ((val = find_in_dict(d, [:V :verbose], true)[1]) !== nothing)
		if (isa(val, Bool) && val) cmd *= " -V"
		else                       cmd *= " -V" * arg2str(val)
		end
	end
	return cmd
end

# ---------------------------------------------------------------------------------------------------
function parse_V_params(cmd::String, d::Dict)
	# Parse the global -V option and the --PAR=val. Return CMD same as input if no options in args
	cmd = parse_V(cmd, d)
	return parse_params(cmd, d)
end

# ---------------------------------------------------------------------------------------------------
function parse_UVXY(cmd::String, d::Dict)
	cmd = parse_V(cmd, d)
	cmd = parse_UXY(cmd, d, [:X :xoff :x_off :x_offset], 'X')
	cmd = parse_UXY(cmd, d, [:Y :yoff :y_off :y_offset], 'Y')
	cmd = parse_UXY(cmd, d, [:U :stamp :time_stamp], 'U')
	return cmd
end

# ---------------------------------------------------------------------------------------------------
function parse_a(cmd::String, d::Dict)
	# Parse the global -a option. Return CMD same as input if no -a option in args
	parse_helper(cmd, d, [:a :aspatial], " -a")
end

function parse_b(cmd::String, d::Dict)
	# Parse the global -b option. Return CMD same as input if no -b option in args
	parse_helper(cmd, d, [:b :binary], " -b")
end

# ---------------------------------------------------------------------------------------------------
function parse_bi(cmd::String, d::Dict)
	# Parse the global -bi option. Return CMD same as input if no -bi option in args
	parse_helper(cmd, d, [:bi :binary_in], " -bi")
end

# ---------------------------------------------------------------------------------------------------
function parse_bo(cmd::String, d::Dict)
	# Parse the global -bo option. Return CMD same as input if no -bo option in args
	parse_helper(cmd, d, [:bo :binary_out], " -bo")
end

# ---------------------------------------------------------------------------------------------------
function parse_c(cmd::String, d::Dict)
	# Most of the work here is because GMT counts from 0 but here we count from 1, so conversions needed
	opt_val = ""
	if ((val = find_in_dict(d, [:c :panel])[1]) !== nothing)
		if (isa(val, Tuple) || isa(val, Array{<:Number}) || isa(val, Integer))
			opt_val = arg2str(val .- 1, ',')
		elseif (isa(val, String) || isa(val, Symbol))
			val = string(val)		# In case it was a symbol
			if ((ind = findfirst(",", val)) !== nothing)	# Shit, user really likes complicating
				opt_val = string(parse(Int, val[1:ind[1]-1]) - 1, ',', parse(Int, val[ind[1]+1:end]) - 1)
			else
				if (val == "" || val == "next")  opt_val = ""
				else                             opt_val = string(parse(Int, val) - 1)
				end
			end
		end
		cmd *= " -c" * opt_val
	end
	return cmd, opt_val
end

# ---------------------------------------------------------------------------------------------------
function parse_d(cmd::String, d::Dict)
	# Parse the global -di option. Return CMD same as input if no -di option in args
	parse_helper(cmd, d, [:d :nodata], " -d")
end

# ---------------------------------------------------------------------------------------------------
function parse_di(cmd::String, d::Dict)
	# Parse the global -di option. Return CMD same as input if no -di option in args
	parse_helper(cmd, d, [:di :nodata_in], " -di")
end

# ---------------------------------------------------------------------------------------------------
function parse_do(cmd::String, d::Dict)
	# Parse the global -do option. Return CMD same as input if no -do option in args
	parse_helper(cmd, d, [:do :nodata_out], " -do")
end

# ---------------------------------------------------------------------------------------------------
function parse_e(cmd::String, d::Dict)
	# Parse the global -e option. Return CMD same as input if no -e option in args
	parse_helper(cmd, d, [:e :pattern], " -e")
end

# ---------------------------------------------------------------------------------
function parse_f(cmd::String, d::Dict)
	# Parse the global -f option. Return CMD same as input if no -f option in args
	parse_helper(cmd, d, [:f :colinfo], " -f")
end

# ---------------------------------------------------------------------------------
function parse_g(cmd::String, d::Dict)
	# Parse the global -g option. Return CMD same as input if no -g option in args
	parse_helper(cmd, d, [:g :gaps], " -g")
end

# ---------------------------------------------------------------------------------
function parse_h(cmd::String, d::Dict)
	# Parse the global -h option. Return CMD same as input if no -h option in args
	parse_helper(cmd, d, [:h :header], " -h")
end

# ---------------------------------------------------------------------------------
parse_i(cmd::String, d::Dict) = parse_helper(cmd, d, [:i :incol], " -i")
parse_j(cmd::String, d::Dict) = parse_helper(cmd, d, [:j :spheric_dist :spherical_dist], " -j")

# ---------------------------------------------------------------------------------
function parse_l(cmd::String, d::Dict)
	cmd_ = add_opt("", 'l', d, [:l :legend],
		(text=("", arg2str, 1), pen=("+d", add_opt_pen), gap="+g", font=("+f", font), justify="+j", header="+h", ncols="+n", size="+s", width="+w", scale="+x"), false)
	# Now make sure blanks in legen text are wrapped in ""
	if ((ind = findfirst("+", cmd_)) !== nothing)
		cmd_ = " -l" * str_with_blancs(cmd_[4:ind[1]-1]) * cmd_[ind[1]:end]
	elseif (cmd_ != "")
		cmd_ = " -l" * str_with_blancs(cmd_[4:end])
	end
	if (IamModern[1])  cmd *= cmd_  end		# l option is only available in modern mode
	return cmd, cmd_
end

# ---------------------------------------------------------------------------------
function parse_n(cmd::String, d::Dict)
	# Parse the global -n option. Return CMD same as input if no -n option in args
	parse_helper(cmd, d, [:n :interp :interpol], " -n")
end

# ---------------------------------------------------------------------------------
function parse_o(cmd::String, d::Dict)
	# Parse the global -o option. Return CMD same as input if no -o option in args
	parse_helper(cmd, d, [:o :outcol], " -o")
end

# ---------------------------------------------------------------------------------
function parse_p(cmd::String, d::Dict)
	# Parse the global -p option. Return CMD same as input if no -p option in args
	parse_helper(cmd, d, [:p :view :perspective], " -p")
end

# ---------------------------------------------------------------------------------------------------
# Parse the global -s option. Return CMD same as input if no -s option in args
parse_s(cmd::String, d::Dict) = parse_helper(cmd, d, [:s :skip_NaN], " -s")

# ---------------------------------------------------------------------------------------------------
# Parse the global -: option. Return CMD same as input if no -: option in args
# But because we can't have a variable called ':' we use only the aliases
parse_swap_xy(cmd::String, d::Dict) = parse_helper(cmd, d, [:yx :swap_xy], " -:")

# ---------------------------------------------------------------------------------------------------
function parse_r(cmd::String, d::Dict)
	# Parse the global -r option. Return CMD same as input if no -r option in args
	parse_helper(cmd, d, [:r :reg :registration], " -r")
end

# ---------------------------------------------------------------------------------------------------
# Parse the global -x option. Return CMD same as input if no -x option in args
parse_x(cmd::String, d::Dict) = parse_helper(cmd, d, [:x :cores :n_threads], " -x")

# ---------------------------------------------------------------------------------------------------
function parse_t(cmd::String, d::Dict)
	opt_val = ""
	if ((val = find_in_dict(d, [:t :alpha :transparency])[1]) !== nothing)
		t = (isa(val, String)) ? parse(Float32, val) : val
		if (t < 1) t *= 100  end
		opt_val = string(" -t", t)
		cmd *= opt_val
	end
	return cmd, opt_val
end

# ---------------------------------------------------------------------------------------------------
function parse_write(cmd::String, d::Dict)
	if ((val = find_in_dict(d, [:write :savefile :|>], true)[1]) !== nothing)
		cmd *=  " > " * val
	end
	return cmd
end

# ---------------------------------------------------------------------------------------------------
function parse_append(cmd::String, d::Dict)
	if ((val = find_in_dict(d, [:append], true)[1]) !== nothing)
		cmd *=  " >> " * val
	end
	return cmd
end

# ---------------------------------------------------------------------------------------------------
function parse_helper(cmd::String, d::Dict, symbs, opt::String)
	# Helper function to the parse_?() global options.
	opt_val = ""
	if ((val = find_in_dict(d, symbs, true)[1]) !== nothing)
		opt_val = opt * arg2str(val)
		cmd *= opt_val
	end
	return cmd, opt_val
end

# ---------------------------------------------------------------------------------------------------
function parse_common_opts(d::Dict, cmd::String, opts::Array{<:Symbol}, first=true)
	opt_p = nothing;	o = ""
	for opt in opts
		if     (opt == :a)  cmd, o = parse_a(cmd, d)
		elseif (opt == :b)  cmd, o = parse_b(cmd, d)
		elseif (opt == :c)  cmd, o = parse_c(cmd, d)
		elseif (opt == :bi) cmd, o = parse_bi(cmd, d)
		elseif (opt == :bo) cmd, o = parse_bo(cmd, d)
		elseif (opt == :d)  cmd, o = parse_d(cmd, d)
		elseif (opt == :di) cmd, o = parse_di(cmd, d)
		elseif (opt == :do) cmd, o = parse_do(cmd, d)
		elseif (opt == :e)  cmd, o = parse_e(cmd, d)
		elseif (opt == :f)  cmd, o = parse_f(cmd, d)
		elseif (opt == :g)  cmd, o = parse_g(cmd, d)
		elseif (opt == :h)  cmd, o = parse_h(cmd, d)
		elseif (opt == :i)  cmd, o = parse_i(cmd, d)
		elseif (opt == :j)  cmd, o = parse_j(cmd, d)
		elseif (opt == :l)  cmd, o = parse_l(cmd, d)
		elseif (opt == :n)  cmd, o = parse_n(cmd, d)
		elseif (opt == :o)  cmd, o = parse_o(cmd, d)
		elseif (opt == :p)  cmd, opt_p = parse_p(cmd, d)
		elseif (opt == :r)  cmd, o = parse_r(cmd, d)
		elseif (opt == :s)  cmd, o = parse_s(cmd, d)
		elseif (opt == :x)  cmd, o = parse_x(cmd, d)
		elseif (opt == :t)  cmd, o = parse_t(cmd, d)
		elseif (opt == :yx) cmd, o = parse_swap_xy(cmd, d)
		elseif (opt == :R)  cmd, o = parse_R(cmd, d)
		elseif (opt == :F)  cmd  = parse_F(cmd, d)
		elseif (opt == :I)  cmd  = parse_inc(cmd, d, [:I :inc], 'I')
		elseif (opt == :J)  cmd, o = parse_J(cmd, d)
		elseif (opt == :JZ) cmd, o = parse_JZ(cmd, d)
		elseif (opt == :UVXY)     cmd = parse_UVXY(cmd, d)
		elseif (opt == :V_params) cmd = parse_V_params(cmd, d)
		elseif (opt == :params)   cmd = parse_params(cmd, d)
		elseif (opt == :write)    cmd = parse_write(cmd, d)
		elseif (opt == :append)   cmd = parse_append(cmd, d)
		end
	end
	if (opt_p !== nothing)		# Restrict the contents of this block to when -p was used
		if (opt_p != "")
			if (opt_p == " -pnone")  current_view[1] = "";	cmd = cmd[1:end-7];	opt_p = ""
			elseif (startswith(opt_p, " -pa") || startswith(opt_p, " -pd") || startswith(opt_p, " -p3"))
				current_view[1] = " -p210/30";	cmd = replace(cmd, opt_p => "") * current_view[1]		# auto, def, 3d
			else                     current_view[1] = opt_p
			end
		elseif (!first && current_view[1] != "")
			cmd *= current_view[1]
		elseif (first)
			current_view[1] = ""		# Ensure we start empty
		end
	end
	return cmd, o
end

# ---------------------------------------------------------------------------------------------------
function parse_these_opts(cmd::String, d::Dict, opts, del=true)
	# Parse a group of options that individualualy would had been parsed as (example):
	# cmd = add_opt(cmd, 'A', d, [:A :horizontal])
	for opt in opts
		#println("-", opt[1], "   ", opt[2])
		cmd = add_opt(cmd, string(opt[1]), d, opt, nothing, del)
	end
	return cmd
end

# ---------------------------------------------------------------------------------------------------
function parse_inc(cmd::String, d::Dict, symbs, opt, del=true)::String
	# Parse the quasi-global -I option. But arguments can be strings, arrays, tuples or NamedTuples
	# At the end we must recreate this syntax: xinc[unit][+e|n][/yinc[unit][+e|n]] or
	if ((val = find_in_dict(d, symbs, del)[1]) !== nothing)
		if (isa(val, Dict))  val = dict2nt(val)  end
		if (isa(val, NamedTuple))
			x = "";	y = "";	u = "";	e = false
			fn = fieldnames(typeof(val))
			for k = 1:length(fn)
				if     (fn[k] == :x)     x  = string(val[k])
				elseif (fn[k] == :y)     y  = string(val[k])
				elseif (fn[k] == :unit)  u  = string(val[k])
				elseif (fn[k] == :extend) e = true
				end
			end
			if (x == "") error("Need at least the x increment")	end
			cmd = string(cmd, " -", opt, x)
			if (u != "")
				u = parse_unit_unit(u)
				if (u != "u")  cmd *= u  end	# "u" is only for the `scatter` modules
			end
			if (e)  cmd *= "+e"  end
			if (y != "")
				cmd = string(cmd, "/", y, u)
				if (e)  cmd *= "+e"  end		# Should never have this and u != ""
			end
		else
			if (opt != "")  cmd  = string(cmd, " -", opt, arg2str(val))
			else            cmd *= arg2str(val)
			end
		end
	end
	return cmd
end

# ---------------------------------------------------------------------------------------------------
function parse_params(cmd::String, d::Dict)
	# Parse the gmt.conf parameters when used from within the modules. Return a --PAR=val string
	# The input to this kwarg can be a tuple (e.g. (PAR,val)) or a NamedTuple (P1=V1, P2=V2,...)

	_cmd = Array{String,1}(undef,1)		# Otherwise Traceur insists this fun was returning a Any
	_cmd = [cmd]
	if ((val = find_in_dict(d, [:conf :par :params], true)[1]) !== nothing)
		if (isa(val, Dict))  val = dict2nt(val)  end
		if (isa(val, NamedTuple))
			fn = fieldnames(typeof(val))
			for k = 1:length(fn)		# Suspect that this is higly inefficient but N is small
				_cmd[1] *= " --" * string(fn[k]) * "=" * string(val[k])
			end
		elseif (isa(val, Tuple))
			_cmd[1] *= " --" * string(val[1]) * "=" * string(val[2])
		else
			@warn("Paramers option BAD usage: is neither a Tuple or a NamedTuple")
		end
		usedConfPar[1] = true
	end
	return _cmd[1]
end

# ---------------------------------------------------------------------------------------------------
function add_opt_pen(d::Dict, symbs, opt::String="", sub::Bool=true, del::Bool=true)
	# Build a pen option. Input can be either a full hard core string or spread in lw (or lt), lc, ls, etc or a tuple
	# If SUB is true (lw, lc, ls) are not seeked because we are parsing a sub-option

	if (opt != "")  opt = " -" * opt  end	# Will become -W<pen>, for example
	out = Array{String,1}(undef,1)
	out = [""]
	pen = build_pen(d, del)					# Either a full pen string or empty ("") (Seeks for lw (or lt), lc, etc)
	if (pen != "")
		out[1] = opt * pen
	else
		if ((val = find_in_dict(d, symbs, del)[1]) !== nothing)
			if (isa(val, Dict))  val = dict2nt(val)  end
			if (isa(val, Tuple))				# Like this it can hold the pen, not extended atts
				if (isa(val[1], NamedTuple))	# Then assume they are all NTs
					for v in val
						d2 = nt2dict(v)			# Decompose the NT and feed it into this-self
						out[1] *= opt * add_opt_pen(d2, symbs, "", true, false)
					end
				else
					out[1] = opt * parse_pen(val)	# Should be a better function
				end
			elseif (isa(val, NamedTuple))		# Make a recursive call. Will screw if used in mix mode
				# This branch is very convoluted and fragile
				d2 = nt2dict(val)				# Decompose the NT and feed into this-self
				t = add_opt_pen(d2, symbs, "", true, false)
				if (t == "")
					d = nt2dict(val)
					out[1] = opt
				else
					out[1] = opt * t
					d = Dict{Symbol,Any}()		# Just let it go straight to end. Returning here seems bugged
				end
			else
				out[1] = opt * arg2str(val)
			end
		end
	end

	if (out[1] == "")		# All further options prepend or append to an existing pen. So, if empty we are donne here.
		return out[1]
	end

	# -W in ps|grdcontour may have extra flags at the begining but take care to not prepend on a blank
	if     (out[1][1] != ' ' && haskey(d, :cont) || haskey(d, :contour))  out[1] = "c" * out[1]
	elseif (out[1][1] != ' ' && haskey(d, :annot))                        out[1] = "a" * out[1]
	end

	# Some -W take extra options to indicate that color comes from CPT
	if (haskey(d, :colored))  out[1] *= "+c"
	else
		if ((val = find_in_dict(d, [:cline :color_line :colot_lines])[1]) !== nothing)  out[1] *= "+cl"  end
		if ((val = find_in_dict(d, [:ctext :color_text :csymbol :color_symbols :color_symbol])[1]) !== nothing)  out[1] *= "+cf"  end
	end
	if (haskey(d, :bezier))  out[1] *= "+s";  del_from_dict(d, [:bezier])  end
	if (haskey(d, :offset))  out[1] *= "+o" * arg2str(d[:offset])   end

	if (out[1] != "")		# Search for eventual vec specs, but only if something above has activated -W
		v = false
		r = helper_arrows(d)
		if (r != "")
			if (haskey(d, :vec_start))  out[1] *= "+vb" * r[2:end];  v = true  end	# r[1] = 'v'
			if (haskey(d, :vec_stop))   out[1] *= "+ve" * r[2:end];  v = true  end
			if (!v)  out[1] *= "+" * r  end
		end
	end

	return out[1]
end

# ---------------------------------------------------------------------------------------------------
function opt_pen(d::Dict, opt::Char, symbs)::String
	# Create an option string of the type -Wpen
	out = ""
	pen = build_pen(d)						# Either a full pen string or empty ("")
	if (!isempty(pen))
		out = string(" -", opt, pen)
	else
		if ((val = find_in_dict(d, symbs)[1]) !== nothing)
			if (isa(val, String) || isa(val, Number) || isa(val, Symbol))
				out = string(" -", opt, val)
			elseif (isa(val, Tuple))	# Like this it can hold the pen, not extended atts
				out = string(" -", opt, parse_pen(val))
			else
				error(string("Nonsense in ", opt, " option"))
			end
		end
	end
	return out
end

# ---------------------------------------------------------------------------------------------------
function parse_pen(pen::Tuple)::String
	# Convert an empty to 3 args tuple containing (width[c|i|p]], [color], [style[c|i|p|])
	len = length(pen)
	s = arg2str(pen[1])					# First arg is different because there is no leading ','
	if (length(pen) > 1)
		s *= ',' * get_color(pen[2])
		if (length(pen) > 2)  s *= ',' * arg2str(pen[3])  end
	end
	return s
end

# ---------------------------------------------------------------------------------------------------
function parse_pen_color(d::Dict, symbs=nothing, del::Bool=false)::String
	# Need this as a separate fun because it's used from modules
	lc = ""
	if (symbs === nothing)  symbs = [:lc :linecolor]  end
	if ((val = find_in_dict(d, symbs, del)[1]) !== nothing)
		lc = string(get_color(val))
	end
	return lc
end

# ---------------------------------------------------------------------------------------------------
function build_pen(d::Dict, del::Bool=false)::String
	# Search for lw, lc, ls in d and create a pen string in case they exist
	# If no pen specs found, return the empty string ""
	lw = add_opt("", "", d, [:lw :linewidth], nothing, del)	# Line width
	if (lw == "")  lw = add_opt("", "", d, [:lt :linethick :linethickness], nothing, del)  end	# Line width
	ls = add_opt("", "", d, [:ls :linestyle], nothing, del)	# Line style
	lc = string(parse_pen_color(d, [:lc :linecolor], del))
	out = ""
	if (lw != "" || lc != "" || ls != "")
		out = lw * "," * lc * "," * ls
		while (out[end] == ',')  out = rstrip(out, ',')  end	# Strip unneeded commas
	end
	return out
end

# ---------------------------------------------------------------------------------------------------
function parse_arg_and_pen(arg::Tuple, sep="/", pen=true, opt="")::String
	# Parse an ARG of the type (arg, (pen)) and return a string. These may be used in pscoast -I & -N
	# OPT is the option code letter including the leading - (e.g. -I or -N). This is only used when
	# the ARG tuple has 4, 6, etc elements (arg1,(pen), arg2,(pen), arg3,(pen), ...)
	# When pen=false we call the get_color function instead
	# SEP is normally "+g" when this function is used in the "parse_arg_and_color" mode
	if (isa(arg[1], String) || isa(arg[1], Symbol) || isa(arg[1], Number))  s = string(arg[1])
	else	error("parse_arg_and_pen: Nonsense first argument")
	end
	if (length(arg) > 1)
		if (isa(arg[2], Tuple))  s *= sep * (pen ? parse_pen(arg[2]) : get_color(arg[2]))
		else                     s *= sep * string(arg[2])		# Whatever that is
		end
	end
	if (length(arg) >= 4) s *= " " * opt * parse_arg_and_pen((arg[3:end]))  end		# Recursive call
	return s
end

# ---------------------------------------------------------------------------------------------------
function arg2str(d::Dict, symbs)
	# Version that allow calls from add_opt()
	if ((val = find_in_dict(d, symbs)[1]) !== nothing)  arg2str(val)  end
end

# ---------------------------------------------------------------------------------------------------
function arg2str(arg, sep='/')
	# Convert an empty, a numeric or string ARG into a string ... if it's not one to start with
	# ARG can also be a Bool, in which case the TRUE value is converted to "" (empty string)
	# SEP is the char separator used when ARG is a tuple or array of numbers
	out = Array{String,1}(undef,1)
	out = [""]
	if (isa(arg, AbstractString) || isa(arg, Symbol))
		out[1] = string(arg)
		if (occursin(" ", out[1]) && !startswith(out[1], "\""))	# Wrap it in quotes
			out[1] = "\"" * out[1] * "\""
		end
	elseif ((isa(arg, Bool) && arg) || isempty_(arg))
		out[1] = ""
	elseif (isa(arg, Number))		# Have to do it after the Bool test above because Bool is a Number too
		out[1] = @sprintf("%.15g", arg)
	elseif (isa(arg, Array{<:Number}) || (isa(arg, Tuple) && !isa(arg[1], String)) )
		#out[1] = join([@sprintf("%.15g/",x) for x in arg])
		out[1] = join([string(x, sep) for x in arg])
		out[1] = rstrip(out[1], sep)		# Remove last '/'
	elseif (isa(arg, Tuple) && isa(arg[1], String))		# Maybe better than above but misses nice %.xxg
		out[1] = join(arg, sep)
	else
		error(@sprintf("arg2str: argument 'arg' can only be a String, Symbol, Number, Array or a Tuple, but was %s", typeof(arg)))
	end
	return out[1]
end

# ---------------------------------------------------------------------------------------------------
function set_KO(first::Bool)
	# Set the O K pair dance
	if (first)  K = true;	O = false
	else        K = true;	O = true;
	end
	return K, O
end

# ---------------------------------------------------------------------------------------------------
function finish_PS_nested(d::Dict, cmd::String, output::String, K::Bool, O::Bool, nested_calls)
	# Finish the PS creating command, but check also if we have any nested module calls like 'coast', 'colorbar', etc
	if ((cmd2 = add_opt_module(d, nested_calls)) !== nothing)  K = true  end
	if (cmd2 !== nothing)  cmd = [cmd; cmd2]  end
	return cmd, K
end

# ---------------------------------------------------------------------------------------------------
function finish_PS(d::Dict, cmd, output::String, K::Bool, O::Bool)
	# Finish a PS creating command. All PS creating modules should use this.
	if (IamModern[1])  return cmd  end		# In Modern mode this fun does not play
	if (isa(cmd, Array{String,1}))			# Need a recursive call here
		for k = 1:length(cmd)
			KK = K;		OO = O
			if (!occursin(" >", cmd[k]))	# Nested calls already have the redirection set
				if (k > 1)  KK = true;	OO = true  end
				cmd[k] = finish_PS(d, cmd[k], output, KK, OO)
			end
		end
		return cmd
	end
	(!O && ((val = find_in_dict(d, [:P :portrait])[1]) === nothing)) && (cmd *= " -P")

	if (K && !O)              opt = " -K"
	elseif (K && O)           opt = " -K -O"
	else                      opt = ""
	end

	if (output != "")
		if (K && !O)          cmd *= opt * " > " * output
		elseif (!K && !O)     cmd *= opt * " > " * output
		elseif (O)            cmd *= opt * " >> " * output
		end
	else
		if ((K && !O) || (!K && !O) || O)  cmd *= opt  end
	end
	return cmd
end

# ---------------------------------------------------------------------------------------------------
function prepare2geotif(d::Dict, cmd, opt_T::String, O::Bool)
	# Prepare automatic settings to allow creating a GeoTIF or a KML from a PS map
	# Makes use of psconvert -W option -W
	function helper2geotif(cmd::String)
		# Strip all -B's and add convenient settings for creating GeoTIFF's and KLM's
		opts = split(cmd, " ");		cmd  = ""
		for opt in opts
			if     (startswith(opt, "-JX12c"))  cmd *= "-JX30cd/0 "		# Default size is too small
			elseif (!startswith(opt, "-B"))     cmd *= opt * " "
			end
		end
		cmd *= " -B0 --MAP_FRAME_TYPE=inside --MAP_FRAME_PEN=0.1,254"
	end

	if (!O && ((val = find_in_dict(d, [:geotif])[1]) !== nothing))		# Only first layer
		if (isa(cmd, Array{String,1})) cmd[1] = helper2geotif(cmd[1])
		else                           cmd    = helper2geotif(cmd)
		end
		if (startswith(string(val), "trans"))  opt_T = " -TG -W+g"  end	# A transparent GeoTIFF
	elseif (!O && ((val = find_in_dict(d, [:kml])[1]) !== nothing))		# Only first layer
		if (!occursin("-JX", cmd) && !occursin("-Jx", cmd))
			@warn("Creating KML requires the use of a cartesian projection of geographical coordinates. Not your case")
			return cmd, opt_T
		end
		if (isa(cmd, Array{String,1})) cmd[1] = helper2geotif(cmd[1])
		else                           cmd    = helper2geotif(cmd)
		end
		if (isa(val, String) || isa(val, Symbol))	# A transparent KML
			if (startswith(string(val), "trans"))  opt_T = " -TG -W+k"
			else                                   opt_T = string(" -TG -W+k", val)		# Whatever 'val' is
			end
		elseif (isa(val, NamedTuple) || isa(val, Dict))
			# [+tdocname][+nlayername][+ofoldername][+aaltmode[alt]][+lminLOD/maxLOD][+fminfade/maxfade][+uURL]
			if (isa(val, Dict))  val = dict2nt(val)  end
			opt_T = add_opt(" -TG -W+k", "", Dict(:kml => val), [:kml],
							(title="+t", layer="+n", layername="+n", folder="+o", foldername="+o", altmode="+a", LOD=("+l", arg2str), fade=("+f", arg2str), URL="+u"))
		end
	end
	return cmd, opt_T
end

# ---------------------------------------------------------------------------------------------------
function add_opt_1char(cmd::String, d::Dict, symbs, del::Bool=true)
	# Scan the D Dict for SYMBS keys and if found create the new option OPT and append it to CMD
	# If DEL == true we remove the found key.
	# The keyword value must be a string, symbol or a tuple of them. We only retain the first character of each item
	# Ex:  GMT.add_opt_1char("", Dict(:N => ("abc", "sw", "x"), :Q=>"datum"), [[:N :geod2aux], [:Q :list]]) == " -Nasx -Qd"
	for opt in symbs
		if ((val = find_in_dict(d, opt, del)[1]) === nothing)  continue  end
		args = ""
		if (isa(val, String) || isa(val, Symbol))
			if ((args = arg2str(val)) != "")  args = args[1]  end
		elseif (isa(val, Tuple))
			for k = 1:length(val)
				args *= arg2str(val[k])[1]
			end
		end
		cmd = string(cmd, " -", opt[1], args)
	end
	return cmd
end

# ---------------------------------------------------------------------------------------------------
function add_opt(cmd::String, opt, d::Dict, symbs, mapa=nothing, del::Bool=true, arg=nothing)::String
	# Scan the D Dict for SYMBS keys and if found create the new option OPT and append it to CMD
	# If DEL == false we do not remove the found key.
	# ARG, is a special case to append to a matrix (complicated thing in Julia)
	# ARG can alse be a Bool, in which case when MAPA is a NT we expand each of its members as sep options
	if ((val = find_in_dict(d, symbs, del)[1]) === nothing)
		if (isa(arg, Bool) && isa(mapa, NamedTuple))	# Make each mapa[i] a mapa[i]key=mapa[i]val
			cmd_ = Array{String,1}(undef,1)
			cmd_ = [""]
			for k in keys(mapa)
				if ((val_ = find_in_dict(d, [k], false)[1]) === nothing)  continue  end
				if (isa(mapa[k], Tuple))  cmd_[1] *= mapa[k][1] * mapa[k][2](d, [k])
				else                      cmd_[1] *= mapa[k] * arg2str(val_)
				end
				del_from_dict(d, [k])		# Now we can delete the key
			end
			if (cmd_[1] != "")  cmd *= " -" * opt * cmd_[1]  end
		end
		return cmd
	end

	args = Array{String,1}(undef,1)
	if (isa(val, Dict))  val = dict2nt(val)  end	# For Py usage
	if (isa(val, NamedTuple) && isa(mapa, NamedTuple))
		args[1] = add_opt(val, mapa, arg)
	elseif (isa(val, Tuple) && length(val) > 1 && isa(val[1], NamedTuple))	# In fact, all val[i] -> NT
		# Used in recursive calls for options like -I, -N , -W of pscoast. Here we assume that opt != ""
		args = [""]
		for k = 1:length(val)
			args[1] *= " -" * opt * add_opt(val[k], mapa, arg)
		end
		return cmd * args[1]
	elseif (isa(mapa, Tuple) && length(mapa) > 1 && isa(mapa[2], Function))	# grdcontour -G
		if (isa(val, NamedTuple))
			if (mapa[2] == helper_decorated)  args[1] = mapa[2](val, true)		# 'true' => single argout
			else                              args[1] = mapa[2](val)			# Case not yet invented
			end
		elseif (isa(val, String))  args[1] = val
		else                       error("The option argument must be a NamedTuple, not a simple Tuple")
		end
	else
		args[1] = arg2str(val)
	end

	#cmd = (opt != "") ? string(cmd, " -", opt, args) : string(cmd, args)
	if (opt != "")  cmd = string(cmd, " -", opt, args[1])
	else            cmd = string(cmd, args[1])
	end

	return cmd
end

# ---------------------------------------------------------------------------------------------------
function genFun(this_key::Symbol, user_input::NamedTuple, mapa::NamedTuple)
	d = nt2dict(mapa)
	if (!haskey(d, this_key))  return  end	# Should be a error?
	out = Array{String,1}(undef,1)
	out = [""]
	key = keys(user_input)					# user_input = (rows=1, fill=:red)
	val_namedTup = d[this_key]				# water=(rows="my", cols="mx", fill=add_opt_fill)
	d = nt2dict(val_namedTup)
	for k = 1:length(user_input)
		if (haskey(d, key[k]))
			val = d[key[k]]
			if (isa(val, Function))
				if (val == add_opt_fill)
					out[1] *= val(Dict(key[k] => user_input[key[k]]))
				end
			else
				out[1] *= string(d[key[k]])
			end
		end
	end
	return out[1]
end

# ---------------------------------------------------------------------------------------------------
function add_opt(nt::NamedTuple, mapa::NamedTuple, arg=nothing)::String
	# Generic parser of options passed in a NT and whose last element is anther NT with the mapping
	# between expanded sub-options names and the original GMT flags.
	# ARG, is a special case to append to a matrix (complicated thing in Julia)
	# Example:
	#	add_opt((a=(1,0.5),b=2), (a="+a",b="-b"))
	# translates to:	"+a1/0.5-b2"
	key = keys(nt);						# The keys actually used in this call
	d = nt2dict(mapa)					# The flags mapping as a Dict (all possible flags of the specific option)
	cmd = "";		cmd_hold = Array{String,1}(undef, 2);	order = zeros(Int,2,1);  ind_o = 0
	for k = 1:length(key)				# Loop over the keys of option's tuple
		if (!haskey(d, key[k]))  continue  end
		if (isa(nt[k], Dict))  nt[k] = dict2nt(nt[k])  end
		if (isa(d[key[k]], Tuple))		# Complexify it. Here, d[key[k]][2] must be a function name.
			if (isa(nt[k], NamedTuple))
				if (d[key[k]][2] == add_opt_fill)
					cmd *= d[key[k]][1] * d[key[k]][2]("", Dict(key[k] => nt[k]), [key[k]])
				else
					local_opt = (d[key[k]][2] == helper_decorated) ? true : nothing		# 'true' means single argout
					cmd *= d[key[k]][1] * d[key[k]][2](nt2dict(nt[k]), local_opt)
				end
			else						#
				if (length(d[key[k]]) == 2)		# Run the function
					cmd *= d[key[k]][1] * d[key[k]][2](Dict(key[k] => nt[k]), [key[k]])
				else					# This branch is to deal with options -Td, -Tm, -L and -D of basemap & psscale
					ind_o += 1
					if (d[key[k]][2] === nothing)  cmd_hold[ind_o] = d[key[k]][1]	# Only flag char and order matters
					elseif (length(d[key[k]][1]) == 2 && d[key[k]][1][1] == '-' && !isa(nt[k], Tuple))	# e.g. -L (&g, arg2str, 1)
						cmd_hold[ind_o] = string(d[key[k]][1][2])	# where g<scalar>
					else		# Run the fun
						cmd_hold[ind_o] = (d[key[k]][1] == "") ? d[key[k]][2](nt[k]) : d[key[k]][1][end] * d[key[k]][2](nt[k])
					end
					order[ind_o]    = d[key[k]][3];				# Store the order of this sub-option
				end
			end
		elseif (isa(d[key[k]], NamedTuple))		#
			if (isa(nt[k], NamedTuple))
				cmd *= genFun(key[k], nt[k], mapa)
			else						# Create a NT where value = key. For example for: surf=(waterfall=:rows,)
				if (!isa(nt[1], Tuple))			# nt[1] may be a symbol, or string. E.g.  surf=(water=:cols,)
					cmd *= genFun(key[k], (; Symbol(nt[1]) => nt[1]), mapa)
				else
					if ((val = find_in_dict(d, [key[1]])[1]) !== nothing)		# surf=(waterfall=(:cols,:red),)
						cmd *= genFun(key[k], (; Symbol(nt[1][1]) => nt[1][1], keys(val)[end] => nt[1][end]), mapa)
					end
				end
			end
		elseif (d[key[k]] == "1")		# Means that only first char in value is retained. Used with units
			t = arg2str(nt[k])
			if (t != "")  cmd *= t[1]
			else          cmd *= "1"	# "1" is itself the flag
			end
		elseif (d[key[k]] != "" && d[key[k]][1] == '|')		# Potentialy append to the arg matrix
			if (isa(nt[k], AbstractArray) || isa(nt[k], Tuple))
				if (isa(nt[k], AbstractArray))  append!(arg, reshape(nt[k], :))
				else                            append!(arg, reshape(collect(nt[k]), :))
				end
			end
			cmd *= d[key[k]][2:end]		# And now append the flag
		elseif (d[key[k]] != "" && d[key[k]][1] == '_')		# Means ignore the content, only keep the flag
			cmd *= d[key[k]][2:end]		# Just append the flag
		elseif (d[key[k]] != "" && d[key[k]][end] == '1')	# Means keep the flag and only first char of arg
			cmd *= d[key[k]][1:end-1] * string(nt[k])[1]
		elseif (d[key[k]] != "" && d[key[k]][end] == '#')	# Means put flag at the end and make this arg first in cmd (coast -W)
			cmd = arg2str(nt[k]) * d[key[k]][1:end-1] * cmd
		else
			cmd *= d[key[k]] * arg2str(nt[k])
		end
	end

	if (ind_o > 0)			# We have an ordered set of flags (-Tm, -Td, -D, etc...). Not so trivial case
		if     (order[1] == 1 && order[2] == 2)  cmd = cmd_hold[1] * cmd_hold[2] * cmd;		last = 2
		elseif (order[1] == 2 && order[2] == 1)  cmd = cmd_hold[2] * cmd_hold[1] * cmd;		last = 1
		else                                     cmd = cmd_hold[1] * cmd;		last = 1
		end
		if (occursin(':', cmd_hold[last]))		# It must be a geog coordinate in dd:mm
			cmd = "g" * cmd
		elseif (length(cmd_hold[last]) > 2)		# Temp patch to avoid parsing single char flags
			rs = split(cmd_hold[last], '/')
			if (length(rs) == 2)
				x = tryparse(Float64, rs[1]);		y = tryparse(Float64, rs[2]);
				if (x !== nothing && y !== nothing && 0 <= x <= 1.0 && 0 <= y <= 1.0 && !occursin(r"[gjJxn]", string(cmd[1])))  cmd = "n" * cmd  end		# Otherwise, either a paper coord or error
			end
		end
	end

	return cmd
end

# ---------------------------------------------------------------------------------------------------
function add_opt(fun::Function, t1::Tuple, t2::NamedTuple, del::Bool, mat)
	# Crazzy shit to allow increasing the arg1 matrix
	if (mat === nothing)  return  fun(t1..., t2, del, mat), mat  end	# psxy error_bars may send mat = nothing
	n_rows, n_cols = size(mat)
	mat = reshape(mat, :)
	cmd = fun(t1..., t2, del, mat)
	mat = reshape(mat, n_rows, :)
	return cmd, mat
end

# ---------------------------------------------------------------------------------------------------
function add_opt(cmd::String, opt, d::Dict, symbs, need_symb::Symbol, args, nt_opts::NamedTuple, del=true)
	# This version specializes in the case where an option may transmit an array, or read a file, with optional flags.
	# When optional flags are used we need to use NamedTuples (the NT_OPTS arg). In that case the NEED_SYMB
	# is the keyword name (a symbol) whose value holds the array. An error is raised if this symbol is missing in D
	# ARGS is a 1-to-3 array of GMT types with in which some may be NOTHING. The value is an array, it will be
	# stored in first non-empty element of ARGS.
	# Example where this is used (plot -Z):  Z=(outline=true, data=[1, 4])

	N_used = 0;		got_one = false
	val,symb = find_in_dict(d, symbs, false)
	if (val !== nothing)
		to_slot = true
		if (isa(val, Dict))  val = dict2nt(val)  end
		if (isa(val, Tuple) && length(val) == 2)
			# This is crazzy trickery to accept also (e.g) C=(pratt,"200k") instead of C=(pts=pratt,dist="200k")
			val = dict2nt(Dict(need_symb=>val[1], keys(nt_opts)[1]=>val[2]))
			d[symb] = val		# Need to patch also the input option
		end
		if (isa(val, NamedTuple))
			di = nt2dict(val)
			if ((val = find_in_dict(di, [need_symb], false)[1]) === nothing)
				error(string(need_symb, " member cannot be missing"))
			end
			if (isa(val, Number) || isa(val, String))	# So that this (psxy) also works:	Z=(outline=true, data=3)
				opt *= string(val)
				to_slot = false
			end
			cmd = add_opt(cmd, opt, d, symbs, nt_opts)
		elseif (isa(val, Array{<:Number}) || isa(val, GMTdataset) || isa(val, Array{<:GMTdataset,1}) || typeof(val) <: AbstractRange)
			if (typeof(val) <: AbstractRange)  val = collect(val)  end
			cmd *= " -" * opt
		elseif (isa(val, String) || isa(val, Symbol) || isa(val, Number))
			cmd *= " -" * opt * arg2str(val)
			to_slot = false
		else
			error(@sprintf("Bad argument type (%s) to option %s", typeof(val), opt))
		end
		if (to_slot)
			for k = 1:length(args)
				if (args[k] === nothing)
					args[k] = val
					N_used = k
					break
				end
			end
		end
		del_from_dict(d, symbs)
		got_one = true
	end
	return cmd, args, N_used, got_one
end

# ---------------------------------------------------------------------------------------------------
function add_opt_cpt(d::Dict, cmd::String, symbs, opt::Char, N_args=0, arg1=nothing, arg2=nothing,
	                 store::Bool=false, def::Bool=false, opt_T::String="", in_bag::Bool=false)
	# Deal with options of the form -Ccolor, where color can be a string or a GMTcpt type
	# SYMBS is normally: [:C :color :cmap]
	# N_args only applyies to when a GMTcpt was transmitted. Than it's either 0, case in which
	# the cpt is put in arg1, or 1 and the cpt goes to arg2.
	# STORE, when true, will save the cpt in the global state
	# DEF, when true, means to use the default cpt (Jet)
	# OPT_T, when != "", contains a min/max/n_slices/+n string to calculate a cpt with n_slices colors between [min max]
	# IN_BAG, if true means that, if not empty, we return the contents of `current_cpt`
	if ((val = find_in_dict(d, symbs)[1]) !== nothing)
		if (isa(val, GMT.GMTcpt))
			if (N_args > 1)  error("Can't send the CPT data via option AND input array")  end
			cmd, arg1, arg2, N_args = helper_add_cpt(cmd, opt, N_args, arg1, arg2, val, store)
		else
			if (opt_T != "")
				cpt = makecpt(opt_T * " -C" * get_color(val))
				cmd, arg1, arg2, N_args = helper_add_cpt(cmd, opt, N_args, arg1, arg2, cpt, store)
			else
				c = get_color(val)
				opt_C = " -" * opt * c		# This is pre-made GMT cpt
				cmd *= opt_C
				if (store && tryparse(Float32, c) === nothing)	# Because if !== nothing then it's number and -Cn is not valid
					try			# Wrap in try because not always (e.g. grdcontour -C) this is a makecpt callable
						global current_cpt = makecpt(opt_C * " -Vq")
					catch
					end
				end
			end
		end
	elseif (def && opt_T != "")						# Requested the use of the default color map
		if (IamModern[1])  opt_T *= " -H"  end		# Piggy back this otherwise we get no CPT back in Modern
		if (haskey(d, :this_cpt) && d[:this_cpt] != "")		# A specific CPT name was requested
			cpt = makecpt(opt_T * " -C" * d[:this_cpt])
		else
			opt_T *= " -Cturbo"
			cpt = makecpt(opt_T)
		end
		cmd, arg1, arg2, N_args = helper_add_cpt(cmd, opt, N_args, arg1, arg2, cpt, store)
	elseif (in_bag)					# If everything else has failed and we have one in the Bag, return it
		global current_cpt
		if (current_cpt !== nothing)
			cmd, arg1, arg2, N_args = helper_add_cpt(cmd, opt, N_args, arg1, arg2, current_cpt, false)
		end
	end
	return cmd, arg1, arg2, N_args
end
# ---------------------
function helper_add_cpt(cmd::String, opt, N_args, arg1, arg2, val, store)
	# Helper function to avoid repeating 3 times the same code in add_opt_cpt
	(N_args == 0) ? arg1 = val : arg2 = val;	N_args += 1
	if (store)  global current_cpt = val  end
	cmd *= " -" * opt
	return cmd, arg1, arg2, N_args
end

# ---------------------------------------------------------------------------------------------------
#add_opt_fill(d::Dict, opt::String="") = add_opt_fill("", d, [d[collect(keys(d))[1]]], opt)	# Use ONLY when len(d) == 1
function add_opt_fill(d::Dict, opt::String="")
	add_opt_fill(d, [collect(keys(d))[1]], opt)	# Use ONLY when len(d) == 1
end
add_opt_fill(d::Dict, symbs, opt="") = add_opt_fill("", d, symbs, opt)
function add_opt_fill(cmd::String, d::Dict, symbs, opt="", del=true)::String
	# Deal with the area fill attributes option. Normally, -G
	if ((val = find_in_dict(d, symbs, del)[1]) === nothing)  return cmd  end
	if (isa(val, Dict))  val = dict2nt(val)  end
	if (opt != "")  opt = string(" -", opt)  end
	return add_opt_fill(val, cmd, opt)
end

function add_opt_fill(val, cmd::String="",  opt="")::String
	# This version can be called directy with VAL as a NT or a string
	if (isa(val, NamedTuple))
		d2 = nt2dict(val)
		cmd *= opt
		if     (haskey(d2, :pattern))     cmd *= 'p' * add_opt("", "", d2, [:pattern])
		elseif (haskey(d2, :inv_pattern)) cmd *= 'P' * add_opt("", "", d2, [:inv_pattern])
		else   error("For 'fill' option as a NamedTuple, you MUST provide a 'patern' member")
		end

		if ((val2 = find_in_dict(d2, [:bg :background], false)[1]) !== nothing)  cmd *= "+b" * get_color(val2)  end
		if ((val2 = find_in_dict(d2, [:fg :foreground], false)[1]) !== nothing)  cmd *= "+f" * get_color(val2)  end
		if (haskey(d2, :dpi))  cmd = string(cmd, "+r", d2[:dpi])  end
	else
		cmd *= string(opt, get_color(val))
	end
	return cmd
end

# ---------------------------------------------------------------------------------------------------
function get_cpt_set_R(d::Dict, cmd0::String, cmd::String, opt_R::String, got_fname, arg1, arg2=nothing, arg3=nothing, prog="")
	# Get CPT either from keyword input of from current_cpt.
	# Also puts -R in cmd when accessing grids from grdimage|view|contour, etc... (due to a GMT bug that doesn't do it)
	# Use CMD0 = "" to use this function from within non-grd modules
	global current_cpt
	cpt_opt_T = ""
	if (isa(arg1, GMTgrid) || isa(arg1, GMTimage))			# GMT bug, -R will not be stored in gmt.history
		range = arg1.range
	elseif (cmd0 != "" && cmd0[1] != '@')
		info = grdinfo(cmd0 * " -C");	range = info[1].data
	end
	if (isa(arg1, GMTgrid) || isa(arg1, GMTimage) || (cmd0 != "" && cmd0[1] != '@'))
		if (current_cpt === nothing && (val = find_in_dict(d, [:C :color :cmap], false)[1]) === nothing)
			# If no cpt name sent in, then compute (later) a default cpt
			cpt_opt_T = @sprintf(" -T%.16g/%.16g/128+n", range[5] - eps()*100, range[6] + eps()*100)
		end
		if (opt_R == "" && (!IamModern[1] || (IamModern[1] && FirstModern[1])) )	# No -R ovewrite by accident
			cmd *= @sprintf(" -R%.14g/%.14g/%.14g/%.14g", range[1], range[2], range[3], range[4])
		end
	end

	N_used = got_fname == 0 ? 1 : 0					# To know whether a cpt will go to arg1 or arg2
	get_cpt = false;	in_bag = true;		# IN_BAG means seek if current_cpt != nothing and return it
	if (prog == "grdview")
		get_cpt = true
		if ((val = find_in_dict(d, [:G :drapefile], false)[1]) !== nothing)
			if (isa(val, Tuple) && length(val) == 3)  get_cpt = false  end	# Playing safe
		end
	elseif (prog == "grdimage" && !isa(arg1, GMTimage) && (arg3 === nothing && !occursin("-D", cmd)))
		get_cpt = true		# This still lieve out the case when the r,g,b were sent as a text.
	elseif (prog == "grdcontour" || prog == "pscontour")	# Here C means Contours but we cheat, so always check if C, color, ... is present
		get_cpt = true;		cpt_opt_T = ""		# This is hell. And what if I want to auto generate a cpt?
		if (prog == "grdcontour" && !occursin("+c", cmd))  in_bag = false  end
	#elseif (prog == "" && current_cpt !== nothing)		# Not yet used
		#get_cpt = true
	end
	if (get_cpt)
		cmd, arg1, arg2, = add_opt_cpt(d, cmd, [:C :color :cmap], 'C', N_used, arg1, arg2, true, true, cpt_opt_T, in_bag)
		N_used = (arg1 !== nothing) + (arg2 !== nothing)
	end

	if (IamModern[1] && FirstModern[1])  FirstModern[1] = false;  end
	return cmd, N_used, arg1, arg2, arg3
end

# ---------------------------------------------------------------------------------------------------
function add_opt_module(d::Dict, symbs)
	#  SYMBS should contain a module name (e.g. 'coast' or 'colorbar'), and if present in D,
	# 'val' can be a NamedTuple with the module's arguments or a 'true'.
	out = Array{String,1}()
	for k = 1:length(symbs)
		r = nothing
		if (haskey(d, symbs[k]))
			val = d[symbs[k]]
			if (isa(val, Dict))  val = dict2nt(val)  end
			if (isa(val, NamedTuple))
				nt = (val..., Vd=2)
				if     (symbs[k] == :coast)    r = coast!(; nt...)
				elseif (symbs[k] == :colorbar) r = colorbar!(; nt...)
				elseif (symbs[k] == :basemap)  r = basemap!(; nt...)
				end
			elseif (isa(val, Number) && (val != 0))		# Allow setting coast=true || colorbar=true
				if     (symbs[k] == :coast)    r = coast!(W=0.5, Vd=2)
				elseif (symbs[k] == :colorbar) r = colorbar!(pos=(anchor="MR",), B="af", Vd=2)
				end
			elseif (symbs[k] == :colorbar && (isa(val, String) || isa(val, Symbol)))
				t = lowercase(string(val)[1])		# Accept "Top, Bot, Left" but default to Right
				anc = (t == 't') ? "TC" : (t == 'b' ? "BC" : (t == 'l' ? "ML" : "MR"))
				r = colorbar!(pos=(anchor=anc,), B="af", Vd=2)
			end
			delete!(d, symbs[k])
		end
		if (r !== nothing)  append!(out, [r])  end
	end
	if (out == [])  return nothing
	else            return out
	end
end

# ---------------------------------------------------------------------------------------------------
function get_color(val)::String
	# Parse a color input. Always return a string
	# color1,color2[,color3,…] colorn can be a r/g/b triplet, a color name, or an HTML hexadecimal color (e.g. #aabbcc
	if (isa(val, String) || isa(val, Symbol) || isa(val, Number))  return isa(val, Bool) ? "" : string(val)  end

	out = Array{String,1}(undef,1)
	out = [""]
	if (isa(val, Tuple))
		for k = 1:length(val)
			if (isa(val[k], Tuple) && (length(val[k]) == 3))
				s = 1
				if (val[k][1] <= 1 && val[k][2] <= 1 && val[k][3] <= 1)  s = 255  end	# colors in [0 1]
				out[1] *= @sprintf("%.0f/%.0f/%.0f,", val[k][1]*s, val[k][2]*s, val[k][3]*s)
			elseif (isa(val[k], Symbol) || isa(val[k], String) || isa(val[k], Number))
				out[1] *= string(val[k],",")
			else
				error("Color tuples must have only one or three elements")
			end
		end
		out[1] = rstrip(out[1], ',')		# Strip last ','``
	elseif ((isa(val, Array) && (size(val, 2) == 3)) || (isa(val, Vector) && length(val) == 3))
		if (isa(val, Vector))  val = val'  end
		if (val[1,1] <= 1 && val[1,2] <= 1 && val[1,3] <= 1)
			copia = val .* 255		# Do not change the original
		else
			copia = val
		end
		out[1] = @sprintf("%.0f/%.0f/%.0f", copia[1,1], copia[1,2], copia[1,3])
		for k = 2:size(copia, 1)
			out[1] = @sprintf("%s,%.0f/%.0f/%.0f", out[1], copia[k,1], copia[k,2], copia[k,3])
		end
	else
		@warn(@sprintf("got this bad data type: %s", typeof(val)))	# Need to split because f julia change in 6.1
		error("GOT_COLOR, got an unsupported data type")
	end
	return out[1]
end

# ---------------------------------------------------------------------------------------------------
function font(d::Dict, symbs)
	if ((val = find_in_dict(d, symbs)[1]) !== nothing)
		font(val)
	#else	# Should not come here anymore, collect returns the dict members in arbitrary order
		#font(collect(values(d))[1])
	end
end
function font(val)
	# parse and create a font string.
	# TODO: either add a NammedTuple option and/or guess if 2nd arg is the font name or the color
	# And this: Optionally, you may append =pen to the fill value in order to draw the text outline with
	# the specified pen; if used you may optionally skip the filling of the text by setting fill to -.
	if (isa(val, String) || isa(val, Number))  return string(val)  end

	s = ""
	if (isa(val, Tuple))
		s = parse_units(val[1])
		if (length(val) > 1)
			s = string(s,',',val[2])
			if (length(val) > 2)
				s = string(s, ',', get_color(val[3]))
			end
		end
	end
	return s
end

# ---------------------------------------------------------------------------------------------------
function parse_units(val)
	# Parse a units string in the form d|e|f|k|n|M|n|s or expanded
	if (isa(val, String) || isa(val, Symbol) || isa(val, Number))  return string(val)  end

	if (isa(val, Tuple) && (length(val) == 2))
		return string(val[1], parse_unit_unit(val[2]))
	else
		error(@sprintf("PARSE_UNITS, got and unsupported data type: %s", typeof(val)))
	end
end

# ---------------------------
function parse_unit_unit(str)::String
	if (isa(str, Symbol))  str = string(str)  end
	if (!isa(str, String))
		error(@sprintf("Argument data type must be String or Symbol but was: %s", typeof(str)))
	end

	if     (str == "e" || str == "meter")  out = "e";
	elseif (str == "M" || str == "mile")   out = "M";
	elseif (str == "nodes")                out = "+n";
	elseif (str == "data")                 out = "u";		# For the `scatter` modules
	else                                   out = string(str[1])		# To be type-stable
	end
	return out
end
# ---------------------------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------------------
axis(nt::NamedTuple; x=false, y=false, z=false, secondary=false) = axis(;x=x, y=y, z=z, secondary=secondary, nt...)
function axis(;x=false, y=false, z=false, secondary=false, kwargs...)
	# Build the (terrible) -B option
	d = KW(kwargs)

	# Before anything else
	if (haskey(d, :none)) return " -B0"  end

	secondary ? primo = 's' : primo = 'p'			# Primary or secondary axis
	if (z)  primo = ""  end							# Z axis have no primary/secondary
	x ? axe = "x" : y ? axe = "y" : z ? axe = "z" : axe = ""	# Are we dealing with a specific axis?

	opt = Array{String,1}(undef,1)					# To force type stability
	opt = [" -B"]
	if ((val = find_in_dict(d, [:frame :axes])[1]) !== nothing)
		if (isa(val, Dict))  val = dict2nt(val)  end
		opt[1] *= helper0_axes(val)
	end

	if (haskey(d, :corners)) opt[1] *= string(d[:corners])  end	# 1234
	#if (haskey(d, :fill))    opt *= "+g" * get_color(d[:fill])  end
	val, symb = find_in_dict(d, [:fill :bg :background], false)
	if (val !== nothing)     opt[1] *= "+g" * add_opt_fill(d, [symb])  end	# Works, but patterns can screw
	if (GMTver > 6.1)
		if ((val = find_in_dict(d, [:Xfill :Xbg :Xwall])[1]) !== nothing)  opt[1] = add_opt_fill(val, opt[1], "+x")  end
		if ((val = find_in_dict(d, [:Yfill :Ybg :Ywall])[1]) !== nothing)  opt[1] = add_opt_fill(val, opt[1], "+y")  end
		if ((p = add_opt_pen(d, [:wall_outline], "+w")) != "")  opt[1] *= p  end
	end
	if (haskey(d, :cube))    opt[1] *= "+b"  end
	if (haskey(d, :noframe)) opt[1] *= "+n"  end
	if (haskey(d, :pole))    opt[1] *= "+o" * arg2str(d[:pole])  end
	if (haskey(d, :title))   opt[1] *= "+t" * str_with_blancs(arg2str(d[:title]))  end

	if (opt[1] == " -B")  opt[1] = ""  end	# If nothing, no -B

	# axes supps
	ax_sup = ""
	if (haskey(d, :seclabel))   ax_sup *= "+s" * str_with_blancs(arg2str(d[:seclabel]))   end

	if (haskey(d, :label))
		opt[1] *= " -B" * primo * axe * "+l"  * str_with_blancs(arg2str(d[:label])) * ax_sup
	else
		if (haskey(d, :xlabel))  opt[1] *= " -B" * primo * "x+l" * str_with_blancs(arg2str(d[:xlabel])) * ax_sup  end
		if (haskey(d, :zlabel))  opt[1] *= " -B" * primo * "z+l" * str_with_blancs(arg2str(d[:zlabel])) * ax_sup  end
		if (haskey(d, :ylabel))
			opt[1] *= " -B" * primo * "y+l" * str_with_blancs(arg2str(d[:ylabel])) * ax_sup
		elseif (haskey(d, :Yhlabel))
			axe != "y" ? opt_L = "y+L" : opt_L = "+L"
			opt[1] *= " -B" * primo * axe * opt_L  * str_with_blancs(arg2str(d[:Yhlabel])) * ax_sup
		end
	end

	# intervals
	ints = Array{String,1}(undef,1)		# To force type stability
	ints[1] = ""
	if (haskey(d, :annot))      ints[1] *= "a" * helper1_axes(d[:annot])  end
	if (haskey(d, :annot_unit)) ints[1] *= helper2_axes(d[:annot_unit])   end
	if (haskey(d, :ticks))      ints[1] *= "f" * helper1_axes(d[:ticks])  end
	if (haskey(d, :ticks_unit)) ints[1] *= helper2_axes(d[:ticks_unit])   end
	if (haskey(d, :grid))       ints[1] *= "g" * helper1_axes(d[:grid])   end
	if (haskey(d, :prefix))     ints[1] *= "+p" * str_with_blancs(arg2str(d[:prefix]))  end
	if (haskey(d, :suffix))     ints[1] *= "+u" * str_with_blancs(arg2str(d[:suffix]))  end
	if (haskey(d, :slanted))
		s = arg2str(d[:slanted])
		if (s != "")
			if (!isnumeric(s[1]) && s[1] != '-' && s[1] != '+')
				s = s[1]
				if (axe == "y" && s != 'p')  error("slanted option: Only 'parallel' is allowed for the y-axis")  end
			end
			ints[1] *= "+a" * s
		end
	end
	if (haskey(d, :custom))
		if (isa(d[:custom], String))  ints[1] *= 'c' * d[:custom]
		else
			if ((r = helper3_axes(d[:custom], primo, axe)) != "")  ints[1] = ints[1] * 'c' * r  end
		end
		# Should find a way to also accept custom=GMTdataset
	elseif (haskey(d, :pi))
		if (isa(d[:pi], Number))
			ints[1] = string(ints[1], d[:pi], "pi")		# (n)pi
		elseif (isa(d[:pi], Array) || isa(d[:pi], Tuple))
			ints[1] = string(ints[1], d[:pi][1], "pi", d[:pi][2])	# (n)pi(m)
		end
	elseif (haskey(d, :scale))
		s = arg2str(d[:scale])
		if     (s == "log")  ints[1] *= 'l'
		elseif (s == "10log" || s == "pow")  ints[1] *= 'p'
		elseif (s == "exp")  ints[1] *= 'p'
		end
	end
	if (haskey(d, :phase_add))
		ints[1] *= "+" * arg2str(d[:phase_add])
	elseif (haskey(d, :phase_sub))
		ints[1] *= "-" * arg2str(d[:phase_sub])
	end
	if (ints[1] != "") opt[1] = " -B" * primo * axe * ints[1] * opt[1]  end

	# Check if ax_sup was requested
	if (opt[1] == "" && ax_sup != "")  opt[1] = " -B" * primo * axe * ax_sup  end

	return opt[1]
end

# ------------------------
function helper0_axes(arg)
	# Deal with the available ways of specifying the WESN(Z),wesn(z),lbrt(u)
	# The solution is very enginious and allows using "left_full", "l_full" or only "l_f"
	# to mean 'W'. Same for others:
	# bottom|bot|b_f(ull);  right|r_f(ull);  t(op)_f(ull);  up_f(ull)  => S, E, N, Z
	# bottom|bot|b_t(icks); right|r_t(icks); t(op)_t(icks); up_t(icks) => s, e, n, z
	# bottom|bot|b_b(are);  right|r_b(are);  t(op)_b(are);  up_b(are)  => b, r, t, u

	if (isa(arg, String) || isa(arg, Symbol))	# Assume that a WESNwesn string was already sent in.
		return string(arg)
	end

	if (!isa(arg, Tuple))
		error(@sprintf("The 'axes' argument must be a String, Symbol or a Tuple but was (%s)", typeof(arg)))
	end

	opt = ""
	for k = 1:length(arg)
		t = string(arg[k])		# For the case it was a symbol
		if (occursin("_f", t))
			if     (t[1] == 'l')  opt *= "W"
			elseif (t[1] == 'b')  opt *= "S"
			elseif (t[1] == 'r')  opt *= "E"
			elseif (t[1] == 't')  opt *= "N"
			elseif (t[1] == 'u')  opt *= "Z"
			end
		elseif (occursin("_t", t))
			if     (t[1] == 'l')  opt *= "w"
			elseif (t[1] == 'b')  opt *= "s"
			elseif (t[1] == 'r')  opt *= "e"
			elseif (t[1] == 't')  opt *= "n"
			elseif (t[1] == 'u')  opt *= "z"
			end
		elseif (occursin("_b", t))
			if     (t[1] == 'l')  opt *= "l"
			elseif (t[1] == 'b')  opt *= "b"
			elseif (t[1] == 'r')  opt *= "r"
			elseif (t[1] == 't')  opt *= "t"
			elseif (t[1] == 'u')  opt *= "u"
			end
		end
	end
	return opt
end

# ------------------------
function helper1_axes(arg)
	# Used by annot, ticks and grid to accept also 'auto' and "" to mean automatic
	out = arg2str(arg)
	if (out != "" && out[1] == 'a')  out = ""  end
	return out
end
# ------------------------
function helper2_axes(arg)
	# Used by
	out = arg2str(arg)
	if (out == "")
		@warn("Empty units. Ignoring this units request.");		return out
	end
	if     (out == "Y" || out == "year")     out = "Y"
	elseif (out == "y" || out == "year2")    out = "y"
	elseif (out == "O" || out == "month")    out = "O"
	elseif (out == "o" || out == "month2")   out = "o"
	elseif (out == "U" || out == "ISOweek")  out = "U"
	elseif (out == "u" || out == "ISOweek2") out = "u"
	elseif (out == "r" || out == "Gregorian_week") out = "r"
	elseif (out == "K" || out == "ISOweekday") out = "K"
	elseif (out == "k" || out == "weekday")  out = "k"
	elseif (out == "D" || out == "date")     out = "D"
	elseif (out == "d" || out == "day_date") out = "d"
	elseif (out == "R" || out == "day_week") out = "R"
	elseif (out == "H" || out == "hour")     out = "H"
	elseif (out == "h" || out == "hour2")    out = "h"
	elseif (out == "M" || out == "minute")   out = "M"
	elseif (out == "m" || out == "minute2")  out = "m"
	elseif (out == "S" || out == "second")   out = "S"
	elseif (out == "s" || out == "second2")  out = "s"
	else
		@warn("Unknown units request (" * out * ") Ignoring it")
		out = ""
	end
	return out
end
# ------------------------
function helper3_axes(arg, primo, axe)
	# Parse the custom annotations arg, save result into a tmp file and return its name

	label = ""
	if (isa(arg, AbstractArray))
		pos = arg
		n_annot = length(pos)
		tipo = fill('a', n_annot)			# Default to annotate
	elseif (isa(arg, NamedTuple) || isa(arg, Dict))
		if (isa(arg, NamedTuple))  d = nt2dict(arg)  end
		if (!haskey(d, :pos))
			error("Custom annotations NamedTuple must contain the member 'pos'")
		end
		pos = d[:pos]
		n_annot = length(pos)
		if ((val = find_in_dict(d, [:type_ :type])[1]) !== nothing)
			if (isa(val, Char) || isa(val, String) || isa(val, Symbol))
				tipo = Array{Any,1}(undef, n_annot)
				for k = 1:n_annot  tipo[k] = val  end
			else
				tipo = val		# Assume it's a good guy, otherwise ...
			end
		else
			tipo = fill('a', n_annot)		# Default to annotate
		end

		if (haskey(d, :label))
			if (!isa(d[:label], Array) || length(d[:label]) != n_annot)
				error("Number of labels in custom annotations must be the same as the 'pos' element")
			end
			label = d[:label]
		end
	else
		@warn("Argument of the custom annotations must be an N-array or a NamedTuple")
		return ""
	end

	temp = "GMTjl_custom_" * primo
	if (axe != "") temp *= axe  end
	fname = joinpath(tempdir(), temp * ".txt")
	fid = open(fname, "w")
	if (label != "")
		for k = 1:n_annot
			println(fid, pos[k], ' ', tipo[k], ' ', label[k])
		end
	else
		for k = 1:n_annot
			println(fid, pos[k], ' ', tipo[k])
		end
	end
	close(fid)
	return fname
end
# ---------------------------------------------------------------------------------------------------

function str_with_blancs(str)
	# If the STR string has spaces enclose it with quotes
	out = string(str)
	if (occursin(" ", out) && !startswith(out, "\""))  out = string("\"", out, "\"")  end
	return out
end

# ---------------------------------------------------------------------------------------------------
vector_attrib(d::Dict, lixo=nothing) = vector_attrib(; d...)	# When comming from add_opt()
vector_attrib(t::NamedTuple) = vector_attrib(; t...)
function vector_attrib(;kwargs...)
	d = KW(kwargs)
	cmd = add_opt("", "", d, [:len :length])
	if (haskey(d, :angle))  cmd = string(cmd, "+a", d[:angle])  end
	if (haskey(d, :middle))
		cmd *= "+m";
		if (d[:middle] == "reverse" || d[:middle] == :reverse)	cmd *= "r"  end
		cmd = helper_vec_loc(d, :middle, cmd)
	else
		for symb in [:start :stop]
			if (haskey(d, symb) && symb == :start)
				cmd *= "+b";
				cmd = helper_vec_loc(d, :start, cmd)
			elseif (haskey(d, symb) && symb == :stop)
				cmd *= "+e";
				cmd = helper_vec_loc(d, :stop, cmd)
			end
		end
	end

	if (haskey(d, :justify))
		t = string(d[:justify])[1]
		if     (t == 'b')  cmd *= "+jb"	# "begin"
		elseif (t == 'e')  cmd *= "+je"	# "end"
		elseif (t == 'c')  cmd *= "+jc"	# "center"
		end
	end

	if ((val = find_in_dict(d, [:half :half_arrow])[1]) !== nothing)
		if (val == "left" || val == :left)	cmd *= "+l"
		else	cmd *= "+r"		# Whatever, gives right half
		end
	end

	if (haskey(d, :fill))
		if (d[:fill] == "none" || d[:fill] == :none) cmd *= "+g-"
		else
			cmd *= "+g" * get_color(d[:fill])		# MUST GET TESTS TO THIS
			if (!haskey(d, :pen))  cmd = cmd * "+p"  end 	# Let FILL paint the whole header (contrary to >= GMT6.1)
		end
	end

	if (haskey(d, :norm))  cmd = string(cmd, "+n", d[:norm])  end

	if (haskey(d, :pole))  cmd *= "+o" * arg2str(d[:pole])  end
	if (haskey(d, :pen))
		if ((p = add_opt_pen(d, [:pen], "")) != "")  cmd *= "+p" * p  end
	end

	if (haskey(d, :shape))
		if (isa(d[:shape], String) || isa(d[:shape], Symbol))
			t = string(d[:shape])[1]
			if     (t == 't')  cmd *= "+h0"		# triang
			elseif (t == 'a')  cmd *= "+h1"		# arrow
			elseif (t == 'V')  cmd *= "+h2"		# V
			else	error("Shape string can be only: 'triang', 'arrow' or 'V'")
			end
		elseif (isa(d[:shape], Number))
			if (d[:shape] < -2 || d[:shape] > 2) error("Numeric shape code must be in the [-2 2] interval.") end
			cmd = string(cmd, "+h", d[:shape])
		else
			error("Bad data type for the 'shape' option")
		end
	end

	if (haskey(d, :trim))  cmd *= "+t" * arg2str(d[:trim])  end
	if (haskey(d, :ang1_ang2) || haskey(d, :start_stop))  cmd *= "+q"  end
	if (haskey(d, :endpoint))  cmd *= "+s"  end
	if (haskey(d, :uv))    cmd *= "+z" * arg2str(d[:uv])  end
	return cmd
end

# ---------------------------------------------------------------------------------------------------
#vector4_attrib(d::Dict, lixo=nothing) = vector4_attrib(; d...)	# When comming from add_opt()
vector4_attrib(t::NamedTuple) = vector4_attrib(; t...)
function vector4_attrib(; kwargs...)
	# Old GMT4 vectors (still supported in GMT6)
	d = KW(kwargs)
	cmd = "t"
	if ((val = find_in_dict(d, [:align :center])[1]) !== nothing)
		c = string(val)[1]
		if     (c == 'h' || c == 'b')  cmd = "h"		# Head
		elseif (c == 'm' || c == 'c')  cmd = "b"		# Middle
		elseif (c == 'p')              cmd = "s"		# Point
		end
	end
	if (haskey(d, :double) || haskey(d, :double_head))  cmd = uppercase(cmd)  end

	if (haskey(d, :norm))  cmd = string(cmd, "n", d[:norm])  end
	if ((val = find_in_dict(d, [:head])[1]) !== nothing)
		if (isa(val, Dict))  val = dict2nt(val)  end
		if (isa(val, NamedTuple))
			ha = "0.075c";	hl = "0.3c";	hw = "0.25c"
			dh = nt2dict(val)
			if (haskey(dh, :arrowwidth))  ha = string(dh[:arrowwidth])  end
			if (haskey(dh, :headlength))  hl = string(dh[:headlength])  end
			if (haskey(dh, :headwidth))   hw = string(dh[:headwidth])   end
			hh = ha * '/' * hl * '/' * hw
		elseif (isa(val, Tuple) && length(val) == 3)  hh = arg2str(val)
		elseif (isa(val, String))                     hh = val		# No checking
		end
		cmd *= hh
	end
	return cmd
end

# -----------------------------------
function helper_vec_loc(d::Dict, symb, cmd::String)
	# Helper function to the 'begin', 'middle', 'end' vector attrib function
	t = string(d[symb])
	if     (t == "line"      )	cmd *= "t"
	elseif (t == "arrow"     )	cmd *= "a"
	elseif (t == "circle"    )	cmd *= "c"
	elseif (t == "tail"      )	cmd *= "i"
	elseif (t == "open_arrow")	cmd *= "A"
	elseif (t == "open_tail" )	cmd *= "I"
	elseif (t == "left_side" )	cmd *= "l"
	elseif (t == "right_side")	cmd *= "r"
	end
	return cmd
end
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
decorated(nt::NamedTuple) = decorated(;nt...)
function decorated(;kwargs...)
	d = KW(kwargs)
	cmd, optD = helper_decorated(d)

	if (haskey(d, :dec2))				# -S~ mode (decorated, with symbols, lines).
		cmd *= ":"
		marca = get_marker_name(d, [:marker :symbol], false)[1]	# This fun lieves in psxy.jl
		if (marca == "")
			cmd = "+sa0.5" * cmd
		else
			cmd *= "+s" * marca
			if ((val = find_in_dict(d, [:size :markersize :symbsize :symbolsize])[1]) !== nothing)
				cmd *= arg2str(val);
			end
		end
		if (haskey(d, :angle))   cmd = string(cmd, "+a", d[:angle])  end
		if (haskey(d, :debug))   cmd *= "+d"  end
		if (haskey(d, :fill))    cmd *= "+g" * get_color(d[:fill])    end
		if (haskey(d, :nudge))   cmd *= "+n" * arg2str(d[:nudge])   end
		if (haskey(d, :n_data))  cmd *= "+w" * arg2str(d[:n_data])  end
		if (optD == "")  optD = "d"  end	# Really need to improve the algo of this
		opt_S = " -S~"
	elseif (haskey(d, :quoted))				# -Sq mode (quoted lines).
		cmd *= ":"
		cmd = parse_quoted(d, cmd)
		if (optD == "")  optD = "d"  end	# Really need to improve the algo of this
		opt_S = " -Sq"
	else									# -Sf mode (front lines).
		if     (haskey(d, :left))  cmd *= "+l"
		elseif (haskey(d, :right)) cmd *= "+r"
		end
		if (haskey(d, :symbol))
			if     (d[:symbol] == "box"      || d[:symbol] == :box)      cmd *= "+b"
			elseif (d[:symbol] == "circle"   || d[:symbol] == :circle)   cmd *= "+c"
			elseif (d[:symbol] == "fault"    || d[:symbol] == :fault)    cmd *= "+f"
			elseif (d[:symbol] == "triangle" || d[:symbol] == :triangle) cmd *= "+t"
			elseif (d[:symbol] == "slip"     || d[:symbol] == :slip)     cmd *= "+s"
			elseif (d[:symbol] == "arcuate"  || d[:symbol] == :arcuate)  cmd *= "+S"
			else   @warn(string("DECORATED: unknown symbol: ", d[:symbol]))
			end
		end
		if (haskey(d, :offset))  cmd *= "+o" * arg2str(d[:offset]);	delete!(d, :offset)  end
		opt_S = " -Sf"
	end

	if (haskey(d, :pen))
		cmd *= "+p"
		if (!isempty_(d[:pen])) cmd *= add_opt_pen(d, [:pen])  end
	end
	return opt_S * optD * cmd
end

# ---------------------------------------------------------
helper_decorated(nt::NamedTuple, compose=false) = helper_decorated(nt2dict(nt), compose)
function helper_decorated(d::Dict, compose=false)
	# Helper function to deal with the gap and symbol size parameters.
	# At same time it's also what we need to call to build up the grdcontour -G option.
	cmd = "";	optD = ""
	val, symb = find_in_dict(d, [:dist :distance :distmap :number])
	if (val !== nothing)
		# The String assumes all is already encoded. Number, Array only accept numerics
		# Tuple accepts numerics and/or strings.
		if (isa(val, String) || isa(val, Number) || isa(val, Symbol))
			cmd = string(val)
		elseif (isa(val, Array) || isa(val, Tuple))
			if (symb == :number)  cmd = "-" * string(val[1], '/', val[2])
			else                  cmd = string(val[1], '/', val[2])
			end
		else
			error("DECORATED: 'dist' (or 'distance') option. Unknown data type.")
		end
		if     (symb == :distmap)  optD = "D"		# Here we know that we are dealing with a -S~ for sure.
		elseif (symb != :number && compose)  optD = "d"		# I feer the case :number is not parsed anywhere
		end
	end
	if (cmd == "")
		val, symb = find_in_dict(d, [:line :Line])
		flag = (symb == :line) ? 'l' : 'L'
		if (val !== nothing)
			if (isa(val, Array{<:Number}))
				if (size(val,2) !=4)
					error("DECORATED: 'line' option. When array, it must be an Mx4 one")
				end
				optD = string(flag,val[1,1],'/',val[1,2],'/',val[1,3],'/',val[1,4])
				for k = 2:size(val,1)
					optD = string(optD,',',val[k,1],'/',val[k,2],'/',val[k,3],'/',val[k,4])
				end
			elseif (isa(val, Tuple))
				if (length(val) == 2 && (isa(val[1], String) || isa(val[1], Symbol)) )
					t1 = string(val[1]);	t2 = string(val[2])		# t1/t2 can also be 2 char or a LongWord justification
					t1 = startswith(t1, "min") ? "Z-" : justify(t1)
					t2 = startswith(t2, "max") ? "Z+" : justify(t2)
					optD = flag * t1 * "/" * t2
				else
					optD = flag * arg2str(val)
				end
			elseif (isa(val, String))
				optD = flag * val
			else
				@warn("DECORATED: lines option. Unknown option data type. Ignoring this.")
			end
		end
	end
	if (cmd == "" && optD == "")
		optD = ((val = find_in_dict(d, [:n_labels :n_symbols])[1]) !== nothing) ? string("n",val) : "n1"
	end
	if (cmd == "")
		if ((val = find_in_dict(d, [:N_labels :N_symbols])[1]) !== nothing)
			optD = string("N", val);
		end
	end
	if (compose)
		return optD * cmd			# For example for grdgradient -G
	else
		return cmd, optD
	end
end

# -------------------------------------------------
function parse_quoted(d::Dict, opt)
	# This function is isolated from () above to allow calling it seperately from grdcontour
	# In fact both -A and -G grdcontour options are almost equal to a decorated line in psxy.
	# So we need a mechanism to call it all at once (psxy) or in two parts (grdcontour).
	cmd = (isa(opt, String)) ? opt : ""			# Need to do this to prevent from calls that don't set OPT
	if (haskey(d, :angle))   cmd  = string(cmd, "+a", d[:angle])  end
	if (haskey(d, :debug))   cmd *= "+d"  end
	if (haskey(d, :clearance ))  cmd *= "+c" * arg2str(d[:clearance]) end
	if (haskey(d, :delay))   cmd *= "+e"  end
	if (haskey(d, :font))    cmd *= "+f" * font(d[:font])    end
	if (haskey(d, :color))   cmd *= "+g" * arg2str(d[:color])   end
	if (haskey(d, :justify)) cmd = string(cmd, "+j", d[:justify]) end
	if (haskey(d, :const_label)) cmd = string(cmd, "+l", str_with_blancs(d[:const_label]))  end
	if (haskey(d, :nudge))   cmd *= "+n" * arg2str(d[:nudge])   end
	if (haskey(d, :rounded)) cmd *= "+o"  end
	if (haskey(d, :min_rad)) cmd *= "+r" * arg2str(d[:min_rad]) end
	if (haskey(d, :unit))    cmd *= "+u" * arg2str(d[:unit])    end
	if (haskey(d, :curved))  cmd *= "+v"  end
	if (haskey(d, :n_data))  cmd *= "+w" * arg2str(d[:n_data])  end
	if (haskey(d, :prefix))  cmd *= "+=" * arg2str(d[:prefix])  end
	if (haskey(d, :suffices)) cmd *= "+x" * arg2str(d[:suffices])  end		# Only when -SqN2
	if (haskey(d, :label))
		if (isa(d[:label], String))
			cmd *= "+L" * d[:label]
		elseif (isa(d[:label], Symbol))
			if     (d[:label] == :header)  cmd *= "+Lh"
			elseif (d[:label] == :input)   cmd *= "+Lf"
			else   error("Wrong content for the :label option. Must be only :header or :input")
			end
		elseif (isa(d[:label], Tuple))
			if     (d[:label][1] == :plot_dist)  cmd *= "+Ld" * string(d[:label][2])
			elseif (d[:label][1] == :map_dist)   cmd *= "+LD" * parse_units(d[:label][2])
			else   error("Wrong content for the :label option. Must be only :plot_dist or :map_dist")
			end
		else
			@warn("'label' option must be a string or a NamedTuple. Since it wasn't I'm ignoring it.")
		end
	end
	return cmd
end
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
function fname_out(d::Dict, del=false)
	# Create a file name in the TMP dir when OUT holds only a known extension. The name is: GMTjl_tmp.ext

	fname = ""
	EXT = FMT[1]
	if ((val = find_in_dict(d, [:savefig :figname :name], del)[1]) !== nothing)
		fname, EXT = splitext(string(val))
		if (EXT == "")  EXT = FMT[1]
		else            EXT = EXT[2:end]
		end
	end
	if (EXT == FMT[1] && haskey(d, :fmt))
		EXT = string(d[:fmt])
		if (del)  delete!(d, :fmt)  end
	end
	if (EXT == "" && !Sys.iswindows())  error("Return an image is only for Windows")  end
	if (1 == length(EXT) > 3)  error("Bad graphics file extension")  end

	ret_ps = false				# To know if we want to return or save PS in mem
	if (haskey(d, :ps))			# In any case this means we want the PS sent back to Julia
		fname = "";		EXT = "ps";		ret_ps = true
		if (del)  delete!(d, :ps)  end
	end

	opt_T = "";
	if (EXT == "pdfg" || EXT == "gpdf")  EXT = "pdg"  end	# Trick to keep the ext with only 3 chars (for GeoPDFs)
	def_name = joinpath(tempdir(), "GMTjl_tmp.ps")
	ext = lowercase(EXT)
	if     (ext == "ps")   EXT = ext
	elseif (ext == "pdf")  opt_T = " -Tf";	EXT = ext
	elseif (ext == "eps")  opt_T = " -Te";	EXT = ext
	elseif (EXT == "PNG")  opt_T = " -TG";	EXT = "png"		# Don't want it to be .PNG
	elseif (ext == "png")  opt_T = " -Tg";	EXT = ext
	elseif (ext == "jpg")  opt_T = " -Tj";	EXT = ext
	elseif (ext == "tif")  opt_T = " -Tt";	EXT = ext
	elseif (ext == "tiff") opt_T = " -Tt -W+g";	EXT = ext
	elseif (ext == "kml")  opt_T = " -Tt -W+k";	EXT = ext
	elseif (ext == "pdg")  opt_T = " -Tf -Qp";	EXT = "pdf"
	else   error(@sprintf("Unknown graphics file extension (.%s)", EXT))
	end

	if (fname != "")  fname *= "." * EXT  end
	return def_name, opt_T, EXT, fname, ret_ps
end

# ---------------------------------------------------------------------------------------------------
function read_data(d::Dict, fname::String, cmd::String, arg, opt_R="", is3D=false, get_info=false)
	# In case DATA holds a file name, read that data and put it in ARG
	# Also compute a tight -R if this was not provided
	if (IamModern[1] && FirstModern[1])  FirstModern[1] = false;  end
	force_get_R = (IamModern[1] && GMTver > 6) ? false : true	# GMT6.0 BUG, modern mode does not auto-compute -R
	#force_get_R = true		# Due to a GMT6.0 BUG, modern mode does not compute -R automatically and 6.1 is not good too
	data_kw = nothing
	if (haskey(d, :data))  data_kw = d[:data]  end
	if (fname != "")       data_kw = fname     end

	cmd, opt_i  = parse_i(cmd, d)		# If data is to be read with some colomn order
	cmd, opt_bi = parse_bi(cmd, d)		# If data is to be read as binary
	cmd, opt_di = parse_di(cmd, d)		# If data missing data other than NaN
	cmd, opt_h  = parse_h(cmd, d)
	cmd, opt_yx = parse_swap_xy(cmd, d)
	if (endswith(opt_yx, "-:"))  opt_yx *= "i"  end		# Need to be -:i not -: to not swap output too
	if (isa(data_kw, String))
		if (((!IamModern[1] && opt_R == "") || get_info) && !convert_syntax[1])	# Then we must read the file to determine -R
			data_kw = gmt("read -Td " * opt_i * opt_bi * opt_di * opt_h * opt_yx * " " * data_kw)
			if (opt_i != "")			# Remove the -i option from cmd. It has done its job
				cmd = replace(cmd, opt_i => "")
				opt_i = ""
			end
			if (opt_h != "")  cmd = replace(cmd, opt_h => "");	opt_h = ""  end
		else							# No need to find -R so let the GMT module read the file
			cmd = data_kw * " " * cmd
			data_kw = nothing			# Prevent that it goes (repeated) into 'arg'
		end
	end

	if (data_kw !== nothing)  arg = data_kw  end		# Finaly move the data into ARG

	info = nothing
	no_R = (opt_R == "" || opt_R[1] == '/' || opt_R == " -Rtight")
	if (((!IamModern[1] && no_R) || (force_get_R && no_R)) && !convert_syntax[1])
		info = gmt("gmtinfo -C" * opt_bi * opt_i * opt_di * opt_h * opt_yx, arg)		# Here we are reading from an original GMTdataset or Array
		if (info[1].data[1] > info[1].data[2])		# Workaround a bug/feature in GMT when -: is arround
			info[1].data[2], info[1].data[1] = info[1].data[1], info[1].data[2]
		end
		if (opt_R != "" && opt_R[1] == '/')	# Modify what will be reported as a -R string
			# Example "/-0.1/0.1/0//" will extend x axis +/- 0.1, set y_min=0 and no change to y_max
			rs = split(opt_R, '/')
			for k = 2:length(rs)
				if (rs[k] != "")
					x = parse(Float64, rs[k])
					(x == 0.0) ? info[1].data[k-1] = x : info[1].data[k-1] += x
				end
			end
		end
		if (opt_R != " -Rtight")
			dx = (info[1].data[2] - info[1].data[1]) * 0.005;	dy = (info[1].data[4] - info[1].data[3]) * 0.005;
			info[1].data[1] -= dx;	info[1].data[2] += dx;	info[1].data[3] -= dy;	info[1].data[4] += dy;
			info[1].data = round_wesn(info[1].data)	# Add a pad if not-tight
		else
			cmd = replace(cmd, " -Rtight" => "")	# Must remove old -R
		end
		if (is3D)
			opt_R = @sprintf(" -R%.12g/%.12g/%.12g/%.12g/%.12g/%.12g", info[1].data[1], info[1].data[2],
			                 info[1].data[3], info[1].data[4], info[1].data[5], info[1].data[6])
		else
			opt_R = @sprintf(" -R%.12g/%.12g/%.12g/%.12g", info[1].data[1], info[1].data[2],
			                 info[1].data[3], info[1].data[4])
		end
		cmd *= opt_R
	end

	if (get_info && info === nothing && !convert_syntax[1])
		info = gmt("gmtinfo -C" * opt_bi * opt_i * opt_di * opt_h * opt_yx, arg)
		if (info[1].data[1] > info[1].data[2])		# Workaround a bug/feature in GMT when -: is arround
			info[1].data[2], info[1].data[1] = info[1].data[1], info[1].data[2]
		end
	end

	return cmd, arg, opt_R, info, opt_i
end

# ---------------------------------------------------------------------------------------------------
round_wesn(wesn::Array{Int}, geo::Bool=false) = round_wesn(float(wesn),geo)
function round_wesn(wesn, geo::Bool=false)
	# Use data range to round to nearest reasonable multiples
	# If wesn has 6 elements (is3D), last two are not modified.
	set = zeros(Bool, 2)
	range = [0.0, 0.0]
	if (wesn[1] == wesn[2])
		wesn[1] -= abs(wesn[1]) * 0.1;	wesn[2] += abs(wesn[2]) * 0.1
		if (wesn[1] == wesn[2])  wesn[1] = -0.1;	wesn[2] = 0.1;	end		# x was = 0
	end
	if (wesn[3] == wesn[4])
		wesn[3] -= abs(wesn[3]) * 0.1;	wesn[4] += abs(wesn[4]) * 0.1
		if (wesn[3] == wesn[4])  wesn[3] = -0.1;	wesn[4] = 0.1;	end		# y was = 0
	end
	range[1] = wesn[2] - wesn[1]
	range[2] = wesn[4] - wesn[3]
	if (geo) 					# Special checks due to periodicity
		if (range[1] > 306.0) 	# If within 15% of a full 360 we promote to 360
			wesn[1] = 0.0;	wesn[2] = 360.0
			set[1] = true
		end
		if (range[2] > 153.0) 	# If within 15% of a full 180 we promote to 180
			wesn[3] = -90.0;	wesn[4] = 90.0
			set[2] = true
		end
	end

	item = 1
	for side = 1:2
		if (set[side]) continue		end		# Done above */
		mag = round(log10(range[side])) - 1.0
		inc = 10.0^mag
		if ((range[side] / inc) > 10.0) inc *= 2.0	end	# Factor of 2 in the rounding
		if ((range[side] / inc) > 10.0) inc *= 2.5	end	# Factor of 5 in the rounding
		s = 1.0
		if (geo) 	# Use arc integer minutes or seconds if possible
			if (inc < 1.0 && inc > 0.05) 				# Nearest arc minute
				s = 60.0;		inc = 1.0
				if ((s * range[side] / inc) > 10.0) inc *= 2.0	end		# 2 arcmin
				if ((s * range[side] / inc) > 10.0) inc *= 2.5	end		# 5 arcmin
			elseif (inc < 0.1 && inc > 0.005) 			# Nearest arc second
				s = 3600.0;		inc = 1.0
				if ((s * range[side] / inc) > 10.0) inc *= 2.0	end		# 2 arcsec
				if ((s * range[side] / inc) > 10.0) inc *= 2.5	end		# 5 arcsec
			end
			wesn[item] = (floor(s * wesn[item] / inc) * inc) / s;	item += 1;
			wesn[item] = (ceil(s * wesn[item] / inc) * inc) / s;	item += 1;
		else
			# Round BB to the next fifth of a decade.
			one_fifth_dec = inc / 5					# One fifth of a decade
			x = (floor(wesn[item] / inc) * inc);
			wesn[item] = x - ceil((x - wesn[item]) / one_fifth_dec) * one_fifth_dec;	item += 1
			x = (ceil(wesn[item] / inc) * inc);
			wesn[item] = x - floor((x - wesn[item]) / one_fifth_dec) * one_fifth_dec;	item += 1
		end
	end
	return wesn
end

# ---------------------------------------------------------------------------------------------------
function find_data(d::Dict, cmd0::String, cmd::String, args...)
	# ...
	got_fname = 0;		data_kw = nothing
	if (haskey(d, :data))  data_kw = d[:data];  delete!(d, :data)  end
	if (cmd0 != "")						# Data was passed as file name
		cmd = cmd0 * " " * cmd
		got_fname = 1
	end

	write_data(d, cmd)			# Check if we need to save to file

	tipo = length(args)
	if (tipo == 1)
		# Accepts "input1"; arg1; data=input1;
		if (got_fname != 0 || args[1] !== nothing)
			return cmd, got_fname, args[1]		# got_fname = 1 => data is in cmd;	got_fname = 0 => data is in arg1
		elseif (data_kw !== nothing)
			if (isa(data_kw, String))
				cmd = data_kw * " " * cmd
				return cmd, 1, args[1]			# got_fname = 1 => data is in cmd
			else
				return cmd, 0, data_kw 		# got_fname = 0 => data is in arg1
			end
		else
			error("Missing input data to run this module.")
		end
	elseif (tipo == 2)			# Two inputs (but second can be optional in some modules)
		# Accepts "input1 input2"; "input1", arg1; "input1", data=input2; arg1, arg2; data=(input1,input2)
		if (got_fname != 0)
			if (args[1] === nothing && data_kw === nothing)
				return cmd, 1, args[1], args[2]		# got_fname = 1 => all data is in cmd
			elseif (args[1] !== nothing)
				return cmd, 2, args[1], args[2]		# got_fname = 2 => data is in cmd and arg1
			elseif (data_kw !== nothing && length(data_kw) == 1)
				return cmd, 2, data_kw, args[2]	# got_fname = 2 => data is in cmd and arg1
			end
		else
			if (args[1] !== nothing && args[2] !== nothing)
				return cmd, 0, args[1], args[2]				# got_fname = 0 => all data is in arg1,2
			elseif (args[1] !== nothing && args[2] === nothing && data_kw === nothing)
				return cmd, 0, args[1], args[2]				# got_fname = 0 => all data is in arg1
			elseif (args[1] !== nothing && args[2] === nothing && data_kw !== nothing && length(data_kw) == 1)
				return cmd, 0, args[1], data_kw			# got_fname = 0 => all data is in arg1,2
			elseif (data_kw !== nothing && length(data_kw) == 2)
				return cmd, 0, data_kw[1], data_kw[2]	# got_fname = 0 => all data is in arg1,2
			end
		end
		error("Missing input data to run this module.")
	elseif (tipo == 3)			# Three inputs
		# Accepts "input1 input2 input3"; arg1, arg2, arg3; data=(input1,input2,input3)
		if (got_fname != 0)
			if (args[1] === nothing && data_kw === nothing)
				return cmd, 1, args[1], args[2], args[3]			# got_fname = 1 => all data is in cmd
			else
				error("Cannot mix input as file names and numeric data.")
			end
		else
			if (args[1] === nothing && args[2] === nothing && args[3] === nothing)
				return cmd, 0, args[1], args[2], args[3]			# got_fname = 0 => ???
			elseif (data_kw !== nothing && length(data_kw) == 3)
				return cmd, 0, data_kw[1], data_kw[2], data_kw[3]	# got_fname = 0 => all data in arg1,2,3
			else
				return cmd, 0, args[1], args[2], args[3]
			end
		end
	end
end

# ---------------------------------------------------------------------------------------------------
function write_data(d::Dict, cmd::String)
	# Check if we need to save to file (redirect stdout)
	if     ((val = find_in_dict(d, [:|>])[1])     !== nothing)  cmd = string(cmd, " > ", val)
	elseif ((val = find_in_dict(d, [:write])[1])  !== nothing)  cmd = string(cmd, " > ", val)
	elseif ((val = find_in_dict(d, [:append])[1]) !== nothing)  cmd = string(cmd, " >> ", val)
	end
	return cmd
end

# ---------------------------------------------------------------------------------------------------
function common_grd(d::Dict, cmd0::String, cmd::String, prog::String, args...)
	n_args = 0
	for k = 1:length(args) if (args[k] !== nothing)  n_args += 1  end  end	# Drop the nothings
	if     (n_args <= 1)  cmd, got_fname, arg1 = find_data(d, cmd0, cmd, args[1])
	elseif (n_args == 2)  cmd, got_fname, arg1, arg2 = find_data(d, cmd0, cmd, args[1], args[2])
	elseif (n_args == 3)  cmd, got_fname, arg1, arg2, arg3 = find_data(d, cmd0, cmd, args[1], args[2], args[3])
	end
	if (arg1 !== nothing && isa(arg1, Array{<:Number}) && startswith(prog, "grd"))  arg1 = mat2grid(arg1)  end
	(n_args <= 1) ? common_grd(d, prog * cmd, arg1) : (n_args == 2) ? common_grd(d, prog * cmd, arg1, arg2) : common_grd(d, prog * cmd, arg1, arg2, arg3)
end

# ---------------------------------------------------------------------------------------------------
function common_grd(d::Dict, cmd::String, args...)
	# This chunk of code is shared by several grdxxx modules, so wrap it in a function
	if (IamModern[1])  cmd = replace(cmd, " -R " => " ")  end
	if (dbg_print_cmd(d, cmd) !== nothing)  return cmd  end		# Vd=2 cause this return
	# First case below is of a ARGS tuple(tuple) with all numeric inputs.
	R = isa(args, Tuple{Tuple}) ? gmt(cmd, args[1]...) : gmt(cmd, args...)
	show_non_consumed(d, cmd)
	return R
end

# ---------------------------------------------------------------------------------------------------
function dbg_print_cmd(d::Dict, cmd)
	# Print the gmt command when the Vd>=1 kwarg was used.
	# In case of convert_syntax = true, just put the cmds in a global var 'cmds_history' used in movie
	if ( ((Vd = find_in_dict(d, [:Vd])[1]) !== nothing) || convert_syntax[1])
		if (convert_syntax[1])
			return update_cmds_history(cmd)
		elseif (Vd >= 0)
			if (Vd >= 2)	# Delete these first before reporting
				del_from_dict(d, [[:show], [:leg :legend], [:box_pos], [:leg_pos], [:figname], [:name], [:savefig]])
			end
			if (length(d) > 0)
				dd = deepcopy(d)		# Make copy so that we can harmlessly delete those below
				del_from_dict(dd, [[:show], [:leg :legend], [:box_pos], [:leg_pos], [:fmt :savefig :figname :name]])
				prog = isa(cmd, String) ? split(cmd)[1] : split(cmd[1])[1]
				if (length(dd) > 0)
					println("Warning: the following options were not consumed in $prog => ", keys(dd))
				end
			end
			if (Vd == 1)
				println(@sprintf("\t%s", cmd))
			elseif (Vd >= 2)
				return cmd
			end
		end
	end
	return nothing
end

# ---------------------------------------------------------------------------------------------------
function update_cmds_history(cmd)
	# Separate into fun to work as a function barrier for var stability
	global cmds_history
	if (length(cmds_history) == 1 && cmds_history[1] == "")		# First time here
		cmds_history[1] = cmd
	else
		push!(cmds_history, cmd)
	end
	return cmd
end

# ---------------------------------------------------------------------------------------------------
function showfig(d::Dict, fname_ps::String, fname_ext::String, opt_T::String, K=false, fname="")
	# Take a PS file, convert it with psconvert (unless opt_T == "" meaning file is PS)
	# and display it in default system viewer
	# FNAME_EXT holds the extension when not PS
	# OPT_T holds the psconvert -T option, again when not PS
	# FNAME is for when using the savefig option

	global current_cpt = nothing		# Reset to empty when fig is finalized
	if (fname == "" && isdefined(Main, :IJulia) && Main.IJulia.inited)	 opt_T = " -Tg"; fname_ext = "png"  end		# In Jupyter, png only
	if (opt_T != "")
		#if (K) gmt("psxy -T -R0/1/0/1 -JX0.001 -O >> " * fname_ps)  end		# Close the PS file first
		if (K) close_PS_file(fname_ps)  end		# Close the PS file first
		if ((val = find_in_dict(d, [:dpi :DPI])[1]) !== nothing)  opt_T *= string(" -E", val)  end
		gmt("psconvert -A1p -Qg4 -Qt4 " * fname_ps * opt_T * " *")
		out = fname_ps[1:end-2] * fname_ext
		if (fname != "")
			out = mv(out, fname, force=true)
		end
	elseif (fname_ps != "")
		#if (K) gmt("psxy -T -R0/1/0/1 -JX0.001 -O >> " * fname_ps)  end		# Close the PS file first
		if (K) close_PS_file(fname_ps)  end		# Close the PS file first
		out = fname_ps
		if (fname != "")
			out = mv(out, fname, force=true)
		end
	end

	if (haskey(d, :show) && d[:show] != 0)
		if (isdefined(Main, :IJulia) && Main.IJulia.inited)		# From Jupyter?
			if (fname == "") display("image/png", read(out))
			else             @warn("In Jupyter you can only visualize png files. File $fname was saved in disk though.")
			end
		else
			@static if (Sys.iswindows()) out = replace(out, "/" => "\\"); run(ignorestatus(`explorer $out`))
			elseif (Sys.isapple()) run(`open $(out)`)
			elseif (Sys.islinux() || Sys.isbsd()) run(`xdg-open $(out)`)
			end
		end
	end
end

# ---------------------------------------------------------------------------------------------------
# Use only to close PS fig and optionally convert/show
function showfig(; kwargs...)
	d = KW(kwargs)
	if (!haskey(d, :show))  d[:show] = true  end		# The default is to show
	finish_PS_module(d, "psxy -R0/1/0/1 -JX0.001c -T -O", "", false, true, true)
end

# ---------------------------------------------------------------------------------------------------
function close_PS_file(fname::AbstractString)
	# Do the equivalesx of "psxy -T -O"
	fid = open(fname, "a")
	write(fid, "\n0 A\nFQ\nO0\n0 0 TM\n\n")
	write(fid, "%%BeginObject PSL_Layer_2\n0 setlinecap\n0 setlinejoin\n3.32550952342 setmiterlimit\n%%EndObject\n")
	write(fid, "\ngrestore\nPSL_movie_label_completion /PSL_movie_label_completion {} def\n")
	write(fid, "PSL_movie_prog_indicator_completion /PSL_movie_prog_indicator_completion {} def\n")
	write(fid, "%PSL_Begin_Trailer\n%%PageTrailer\nU\nshowpage\n\n%%Trailer\n\nend\n%%EOF")
	close(fid)
end

# ---------------------------------------------------------------------------------------------------
function isempty_(arg)
	# F... F... it's a shame having to do this
	if (arg === nothing)  return true  end
	try
		vazio = isempty(arg)
		return vazio
	catch
		return false
	end
end

# ---------------------------------------------------------------------------------------------------
function put_in_slot(cmd::String, val, opt::Char, args)
	# Find the first non-empty slot in ARGS and assign it the Val of d[:symb]
	# Return also the index of that first non-empty slot in ARGS
	k = 1
	for arg in args					# Find the first empty slot
		if (isempty_(arg))
			cmd = string(cmd, " -", opt)
			break
		end
		k += 1
	end
	return cmd, k
end

## ---------------------------------------------------------------------------------------------------
function finish_PS_module(d::Dict, cmd, opt_extra::String, K::Bool, O::Bool, finish::Bool, args...)
	# FNAME_EXT hold the extension when not PS
	# OPT_EXTRA is used by grdcontour -D or pssolar -I to not try to create and view an img file

	output, opt_T, fname_ext, fname, ret_ps = fname_out(d, true)
	(ret_ps) && (output = "")  							# Here we don't want to save to file
	cmd, opt_T = prepare2geotif(d, cmd, opt_T, O)		# Settings for the GeoTIFF and KML cases
	(finish) && (cmd = finish_PS(d, cmd, output, K, O))

	if ((r = dbg_print_cmd(d, cmd)) !== nothing)  return r  end 	# For tests only
	img_mem_layout[1] = add_opt("", "", d, [:layout])
	if (img_mem_layout[1] == "images")  img_mem_layout[1] = "I   "  end	# Special layout for Images.jl

	if (fname_ext != "ps" && fname_ext != "eps")	# Exptend to a larger paper size (5 x A0)
		if (isa(cmd, Array{String, 1}))  cmd[1] *= " --PS_MEDIA=11900x16840"
		else                             cmd    *= " --PS_MEDIA=11900x16840"
		end
	end

	if (isa(cmd, Array{String, 1}))
		for k = 1:length(cmd)
			is_psscale = (startswith(cmd[k], "psscale") || startswith(cmd[k], "colorbar"))
			is_pscoast = (startswith(cmd[k], "pscoast") || startswith(cmd[k], "coast"))
			is_basemap = (startswith(cmd[k], "psbasemap") || startswith(cmd[k], "basemap"))
			if (k > 1 && is_psscale && !isa(args[1], GMTcpt))	# Ex: imshow(I, cmap=C, colorbar=true)
				cmd2, arg1, = add_opt_cpt(d, cmd[k], [:C :color :cmap], 'C', 0, nothing, nothing, false, false, "", true)
				if (arg1 === nothing)
					@warn("No cmap found to use in colorbar. Ignoring this command.");	continue
				end
				P = gmt(cmd[k], arg1)
				continue
			elseif (k > 1 && (is_pscoast || is_basemap) && (isa(args[1], GMTimage) || isa(args[1], GMTgrid)))
				proj4 = args[1].proj4
				if ((proj4 != "") && !startswith(proj4, "+proj=lat") && !startswith(proj4, "+proj=lon"))
					opt_J = replace(proj4, " " => "")
					lims = args[1].range
					D = mapproject([lims[1] lims[3]; lims[2] lims[4]], J=opt_J, I=true)
					mm = extrema(D[1].data, dims=1)
					opt_R = @sprintf(" -R%f/%f/%f/%f+r ", mm[1][1],mm[2][1],mm[1][2],mm[2][2])
					o = scan_opt(cmd[1], "-J")
					if     (o[1] == 'X')  size_ = "+width=" * o[2:end]
					elseif (o[1] == 'x')  size_ = "+scale=" * o[2:end]
					else   @warn("Could not find the right fig size used. Result will be wrong");  size_ = ""
					end
					cmd[k] = replace(cmd[k], " -J" => " -J" * opt_J * size_)
					cmd[k] = replace(cmd[k], " -R" => opt_R)
				end
			end
			P = gmt(cmd[k], args...)
		end
	else
		P = gmt(cmd, args...)
	end

	if (!IamModern[1])  digests_legend_bag(d, true)  end		# Plot the legend if requested

	if (usedConfPar[1])				# Hacky shit to force start over when --PAR options were use
		usedConfPar[1] = false;		gmt("destroy")
	end

	if (!IamModern[1])
		if (fname_ext == "" && opt_extra == "")		# Return result as an GMTimage
			P = showfig(d, output, fname_ext, "", K)
			gmt("destroy")							# Returning a PS screws the session
		elseif ((haskey(d, :show) && d[:show] != 0) || fname != "" || opt_T != "")
			showfig(d, output, fname_ext, opt_T, K, fname)
		end
	end
	show_non_consumed(d, cmd)
	return P
end

# --------------------------------------------------------------------------------------------------
function show_non_consumed(d::Dict, cmd)
	# First delete some that could not have been delete earlier (from legend for example)
	del_from_dict(d, [[:show], [:leg :legend], [:box_pos], [:leg_pos], [:P :portrait]])
	if (length(d) > 0)
		prog = isa(cmd, String) ? split(cmd)[1] : split(cmd[1])[1]
		println("Warning: the following options were not consumed in $prog => ", keys(d))
	end	
end

# --------------------------------------------------------------------------------------------------
mutable struct legend_bag
	label::Array{String,1}
	cmd::Array{String,1}
end

# --------------------------------------------------------------------------------------------------
function put_in_legend_bag(d::Dict, cmd, arg=nothing)
	# So far this fun is only called from plot() and stores line/symbol info in global var LEGEND_TYPE
	global legend_type

	cmd_ = cmd									# Starts to be just a shallow copy
	if (isa(arg, Array{<:GMTdataset,1}))		# Multi-segments can have different settings per line
		(isa(cmd, String)) ? cmd_ = deepcopy([cmd]) : cmd_ = deepcopy(cmd)
		lix, penC, penS = break_pen(scan_opt(arg[1].header, "-W"))
		penT, penC_, penS_ = break_pen(scan_opt(cmd_[end], "-W"))
		(penC == "") && (penC = penC_)
		(penS == "") && (penS = penS_)
		cmd_[end] = "-W" * penT * ',' * penC * ',' * penS * " " * cmd_[end]	# Trick to make the parser find this pen
		pens = Array{String,1}(undef,length(arg)-1)
		for k = 1:length(arg)-1
			t = scan_opt(arg[k+1].header, "-W")
			if     (t == "")      pens[k] = " -W0.5"
			elseif (t[1] == ',')  pens[k] = " -W" * penT * t		# Can't have, e.g., ",,230/159/0" => Crash
			else                  pens[k] = " -W" * penT * ',' * t
			end
		end
		append!(cmd_, pens)			# Append the 'pens' var to the input arg CMD

		lab = Array{String,1}(undef,length(arg))
		if ((val = find_in_dict(d, [:lab :label])[1]) !== nothing)		# Have label(s)
			if (!isa(val, Array))				# One single label, take it as a label prefix
				for k = 1:length(arg)  lab[k] = string(val,k)  end
			else
				for k = 1:min(length(arg), length(val))  lab[k] = string(val[k],k)  end
				if (length(val) < length(arg))	# Probably shit, but don't error because of it
					for k = length(val)+1:length(arg)  lab[k] = string(val[end],k)  end
				end
			end
		else
			for k = 1:length(arg)  lab[k] = string('y',k)  end
		end
	elseif ((val = find_in_dict(d, [:lab :label])[1]) !== nothing)
		lab = [val]
	elseif (legend_type === nothing)
		lab = ["y1"]
	else
		lab = [@sprintf("y%d", size(legend_type.label, 1))]
	end

	if ((isa(cmd_, Array{String, 1}) && !occursin("-O", cmd_[1])) || (isa(cmd_, String) && !occursin("-O", cmd_)))
		legend_type = nothing					# Make sure that we always start with an empty one
	end

	if (legend_type === nothing)
		legend_type = legend_bag(Array{String,1}(undef,1), Array{String,1}(undef,1))
		legend_type.cmd = (isa(cmd_, String)) ? [cmd_] : cmd_
		legend_type.label = lab
	else
		isa(cmd_, String) ? append!(legend_type.cmd, [cmd_]) : append!(legend_type.cmd, cmd_)
		append!(legend_type.label, lab)
	end
	return nothing
end

# --------------------------------------------------------------------------------------------------
function digests_legend_bag(d::Dict, del=false)
	# Plot a legend if the leg or legend keywords were used. Legend info is stored in LEGEND_TYPE global variable
	global legend_type

	if ((val = find_in_dict(d, [:leg :legend], del)[1]) !== nothing)
		(legend_type === nothing) && @warn("This module does not support automatic legends") && return

		fs = 10					# Font size in points
		symbW = 0.75			# Symbol width. Default to 0.75 cm (good for lines)
		nl  = length(legend_type.label)
		leg = Array{String,1}(undef,nl)
		for k = 1:nl											# Loop over number of entries
			if ((symb = scan_opt(legend_type.cmd[k], "-S")) == "")  symb = "-"
			else                                                    symbW_ = symb[2:end];	symb = symb[1]
			end
			if ((fill = scan_opt(legend_type.cmd[k], "-G")) == "")  fill = "-"  end
			pen  = scan_opt(legend_type.cmd[k],  "-W");
			(pen == "" && symb != "-" && fill != "-") ? pen = "-" : (pen == "" ? pen = "0.25p" : pen = pen)
			if (symb == "-")
				leg[k] = @sprintf("S %.3fc %s %.2fc %s %s %.2fc %s",
				                  symbW/2, symb, symbW, fill, pen, symbW+0.14, legend_type.label[k])
			else
				leg[k] = @sprintf("S - %s %s %s %s - %s", symb, symbW_, fill, pen, legend_type.label[k])
			end
		end

		lab_width = maximum(length.(legend_type.label[:])) * fs / 72 * 2.54 * 0.55 + 0.15	# Guess label width in cm
		if ((opt_D = add_opt("", "", d, [:leg_pos :legend_pos :legend_position],
			(map_coord="g",plot_coord="x",norm="n",pos="j",width="+w",justify="+j",spacing="+l",offset="+o"))) == "")
			just = (isa(val, String) || isa(val, Symbol)) ? justify(val) : "TR"		# "TR" is the default
			opt_D = @sprintf("j%s+w%.3f+o0.1", just, symbW*1.2 + lab_width)
		else
			if (opt_D[1] != 'j' && opt_D[1] != 'g' && opt_D[1] != 'x' && opt_D[1] != 'n')  opt_D = "jTR" * opt_D  end
			if (!occursin("+w", opt_D))  opt_D = @sprintf("%s+w%.3f", opt_D, symbW*1.2 + lab_width)  end
			if (!occursin("+o", opt_D))  opt_D *= "+o0.1"  end
		end

		if ((opt_F = add_opt("", "", d, [:box_pos :box_position],
			(clearance="+c", fill=("+g", add_opt_fill), inner="+i", pen=("+p", add_opt_pen), rounded="+r", shade="+s"))) == "")
			opt_F = "+p0.5+gwhite"
		else
			if (!occursin("+p", opt_F))  opt_F *= "+p0.5"    end
			if (!occursin("+g", opt_F))  opt_F *= "+gwhite"  end
		end
		legend!(text_record(leg), F=opt_F, D=opt_D, par=(:FONT_ANNOT_PRIMARY, fs))
		legend_type = nothing			# Job done, now empty the bag
	end
	return nothing
end

# --------------------------------------------------------------------------------------------------
function scan_opt(cmd::String, opt::String)
	# Scan the CMD string for the OPT option. Note OPT mut be a 2 chars -X GMT option.
	out = ""
	if ((ind = findfirst(opt, cmd)) !== nothing)  out, = strtok(cmd[ind[1]+2:end])  end
	return out
end

# --------------------------------------------------------------------------------------------------
function break_pen(pen::AbstractString)
	# Break a pen string in its form thick,color,style into its constituints
	# Absolutely minimalist. Will fail if -Wwidth,color,style pattern is not followed.

	ps = split(pen, ',')
	nc = length(ps)
	if     (nc == 1)  penT = ps[1];    penC = "";       penS = "";
	elseif (nc == 2)  penT = ps[1];    penC = ps[2];    penS = "";
	else              penT = ps[1];    penC = ps[2];    penS = ps[3];
	end
	return penT, penC, penS
end

# --------------------------------------------------------------------------------------------------
function justify(arg)
	# Take a string or symbol in ARG and return the two chars justification code.
	if (isa(arg, Symbol))  arg = string(arg)  end
	if (length(arg) == 2)  return arg  end 		# Assume it's already the 2 chars code (no further checking)
	arg = lowercase(arg)
	if     (startswith(arg, "topl"))     out = "TL"
	elseif (startswith(arg, "middlel"))  out = "ML"
	elseif (startswith(arg, "bottoml"))  out = "BL"
	elseif (startswith(arg, "topc"))     out = "TC"
	elseif (startswith(arg, "middlec"))  out = "MC"
	elseif (startswith(arg, "bottomc"))  out = "BC"
	elseif (startswith(arg, "topr"))     out = "TR"
	elseif (startswith(arg, "middler"))  out = "MR"
	elseif (startswith(arg, "bottomr"))  out = "BR"
	else
		@warn("Justification code provided ($arg) is not valid. Defaulting to TopRight")
		out = "TR"
	end
	return out
end

# --------------------------------------------------------------------------------------------------
function monolitic(prog::String, cmd0::String, args...)
	# Run this module in the monolithic way. e.g. [outs] = gmt("module args",[inputs])
	return gmt(prog * " " * cmd0, args...)
end

# --------------------------------------------------------------------------------------------------
function peaks(; N=49, grid=true)
	x,y = meshgrid(range(-3,stop=3,length=N))

	z =  3 * (1 .- x).^2 .* exp.(-(x.^2) - (y .+ 1).^2) - 10*(x./5 - x.^3 - y.^5) .* exp.(-x.^2 - y.^2)
	   - 1/3 * exp.(-(x .+ 1).^2 - y.^2)

	if (grid)
		x = collect(range(-3,stop=3,length=N))
		y = deepcopy(x)
		z = Float32.(z)
		G = GMTgrid("", "", 0, [x[1], x[end], y[1], y[end], minimum(z), maximum(z)], [x[2]-x[1], y[2]-y[1]],
					0, NaN, "", "", "", x, y, z, "x", "y", "z", "")
		return G
	else
		return x,y,z
	end
end

meshgrid(v::AbstractVector) = meshgrid(v, v)
function meshgrid(vx::AbstractVector{T}, vy::AbstractVector{T}) where T
	m, n = length(vy), length(vx)
	vx = reshape(vx, 1, n)
	vy = reshape(vy, m, 1)
	(repeat(vx, m, 1), repeat(vy, 1, n))
end

function meshgrid(vx::AbstractVector{T}, vy::AbstractVector{T}, vz::AbstractVector{T}) where T
	m, n, o = length(vy), length(vx), length(vz)
	vx = reshape(vx, 1, n, 1)
	vy = reshape(vy, m, 1, 1)
	vz = reshape(vz, 1, 1, o)
	om = ones(Int, m)
	on = ones(Int, n)
	oo = ones(Int, o)
	(vx[om, :, oo], vy[:, on, oo], vz[om, on, :])
end

# --------------------------------------------------------------------------------------------------
function tic()
    t0 = time_ns()
    task_local_storage(:TIMERS, (t0, get(task_local_storage(), :TIMERS, ())))
    return t0
end

function _toq()
    t1 = time_ns()
    timers = get(task_local_storage(), :TIMERS, ())
    if timers === ()
        error("`toc()` without `tic()`")
    end
    t0 = timers[1]::UInt64
    task_local_storage(:TIMERS, timers[2])
    (t1-t0)/1e9
end

function toc(V=true)
    t = _toq()
    if (V)  println("elapsed time: ", t, " seconds")  end
    return t
end
