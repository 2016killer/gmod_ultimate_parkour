AddCSLuaFile()

VManip:RegisterAnim("dp_vault",
    {
        ["model"]="weapons/c_vmanipdh2p.mdl",
        ["lerp_peak"]=0.4,
        ["lerp_speed_in"]=1,
        ["lerp_speed_out"]=0.8,
        ["lerp_curve"]=0.5,
        ["speed"]=3
    }
)

VManip:RegisterAnim("dp_catch",
    {
        ["model"]="weapons/c_vmanipdh2p.mdl",
        ["lerp_peak"]=1,
        ["lerp_speed_in"]=12,
        ["lerp_speed_out"]=12,
        ["lerp_curve"]=1,
        ["speed"]=2
    }
)


VMLegs:RegisterAnim("dp_lazyvault", 
    {
        ["model"]="c_vmaniplegsdh2p.mdl",
        ["speed"]=1.5,
        ["forwardboost"]=2,
        ["upwardboost"]=-5
    }
)


VMLegs:RegisterAnim("dp_monkeyvault", 
    {
        ["model"]="c_vmaniplegsdh2p.mdl",
        ["speed"]=1.2,
        ["forwardboost"]=-10,
        ["upwardboost"]=-5
    }
)

