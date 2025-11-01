AddCSLuaFile()

local author = 'mtbNTB'
local handModel = string.format('weapons/dp_hand_%s.mdl', author)
local legsModel = string.format('dp_legs_%s.mdl', author)

local animname = function(str)
    return string.format('dp_%s_%s', str, author)
end

VManip:RegisterAnim(animname('catch'),
    {
        ["model"]=handModel,
        ["lerp_peak"]=1,
        ["lerp_speed_in"]=12,
        ["lerp_speed_out"]=12,
        ["lerp_curve"]=1,
        ["speed"]=2
    }
)


VMLegs:RegisterAnim(animname('lazy'), 
    {
        ["model"]=legsModel,
        ["speed"]=1.5,
        ["forwardboost"]=2,
        ["upwardboost"]=-5
    }
)


VMLegs:RegisterAnim(animname('monkey'), 
    {
        ["model"]=legsModel,
        ["speed"]=1.2,
        ["forwardboost"]=-10,
        ["upwardboost"]=-5
    }
)

author = 'BaiLang'
handModel = string.format('weapons/dp_hand_%s.mdl', author)
legsModel = string.format('dp_legs_%s.mdl', author)
animname = function(str)
    return string.format('dp_%s_%s', str, author)
end

VManip:RegisterAnim(animname('catch'),
    {
        ["model"]=handModel,
        ["lerp_peak"]=1,
        ["lerp_speed_in"]=12,
        ["lerp_speed_out"]=12,
        ["lerp_curve"]=1,
        ["speed"]=2
    }
)


VMLegs:RegisterAnim(animname('lazy'), 
    {
        ["model"]=legsModel,
        ["speed"]=1.5,
        ["forwardboost"]=2,
        ["upwardboost"]=-5
    }
)


VMLegs:RegisterAnim(animname('monkey'), 
    {
        ["model"]=legsModel,
        ["speed"]=1.2,
        ["forwardboost"]=-10,
        ["upwardboost"]=-5
    }
)


author = nil
handModel = nil
legsModel = nil
animname = nil
