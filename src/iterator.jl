struct DiskIterState{GCh,ChS,ChD,OCDI,OCDS,ICI,ICS,OII,OIS}
    gridchunks::GCh
    chunkdata::ChD
    chunkstate::ChS
    otherchunkinds::OCDI
    otherchunkstate::OCDS
    innercolind::ICI
    innercolstate::ICS
    otherinnerinds::OII
    otherinnerstate::OIS
end

macro implement_iteration(t)
quote
function Base.iterate(a::$t)
    gridchunks = eachchunk(a)
    chunkdata = []
    chunkgridsize = gridchunks.chunkgridsize
    ii = iterate(gridchunks)
    ii === nothing && return nothing
    cifirst, chunkstate = ii

    chunkdata, chunkstate, innercolind, innercolstate, otherinnerinds, otherinnerstate = DiskArrays.nextchunk(gridchunks, chunkdata, chunkstate)

    firstval = firstchunkdata[innercolind, otherinnerind.I...]
    firststate = DiskIterState(
        gridchunks, chunkdata, chunkstate, otherchunkinds, otherchunkstate, 
        innercolind, innercolstate, otherinnerinds, otherinnerstate
    )

    return firstval, firststate
end
function Base.iterate(a::$t, state)
    # Iterate inner state of chunk
    gridchunks = state.gridchunks
    chunkdata = state.chunkdata
    innercolind = state.innercolind
    innercolstate = state.innercolstate
    chunkcolind = state.chunkcolind
    chunkcolstate = state.chunkcolstate
    otherinnerinds = state.otherinnerinds
    otherinnerstate = state.otherinnerstate

    ii = iterate(innercolind, innercolstate)
    if ii === nothing # inner column iteration has finished
        chi = iterate(chunkcolinds, chunkcolstate)
        if chi === nothing # chunk column iteration has finished
            odi = iterate(otherinnerinds, otherinnerstate)
            if odi === nothing # otherinners iteration has finished - new chunk column
                ochdi = iterate(otherchunkinds, otherchunkstate)
                ochdi === nothing && return nothing
            else
                otherinnerinds, otherinnerstate = ochdi
            end
        else
            chunkcolind, chunkcolstate = chi 
            if length(chunkdata) > chunkcolind
                chunkdata, chunkstate, innercolind, innercolstate, otherinnerinds, otherinnerstate = DiskArrays.nextchunk(gridchunks, chunkdata, chunkstate)
            end
        end
    end

    innercolnext, innerstate = ii

    newval = chunkdata[chunkcolind][innercolnext, otherinnerstate.I...]
    newstate = DiskIterState(
        gridchunks, chunkdata, chunkstate, otherchunkinds, otherchunkstate, 
        innercolind, innercolstate, otherinnerinds, otherinnerstate
    )

    return newval, newstate
end
end
end

function nextchunk(gridchunks, chunkdata, chunkstate)
    cii = iterate(gridchunks, chunkstate)
    cinow, chunkstate = cii
    ranges = toRanges(cinow)
    thischunkdata = a[ranges...]
    chunkdata = [chunkdata..., thischunkdata]

    innercolind = ranges[1]
    ii = iterate(innerinds)
    ii === nothing && return nothing
    innercolind, innercolstate = ii

    otherinnerinds = CartesianIndices(Base.tail(ranges))
    oi = iterate(otherinds)
    oi === nothing && return nothing
    otherinnerind, otherinnnerstate = oi
    return chunkdata, chunkstate, innercolind, innercolstate, otherinnerinds, otherinnerstate
end
