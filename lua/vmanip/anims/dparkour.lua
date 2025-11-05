AddCSLuaFile()

local author = 'BaiLang'
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
        ["speed"]=6
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

VMLegs.RegisterAnimCollection = function(self, collectionName, anim)
    if not isstring(anim) then
        print(string.format('RegisterAnimCollection: anim "%s" is not a string', anim))
        return
    end
    self.AnimCollection = self.AnimCollection or {}
    self.AnimCollection[collectionName] = self.AnimCollection[collectionName] or {}
    table.insert(self.AnimCollection[collectionName], anim)
end


VManip.RegisterAnimCollection = VMLegs.RegisterAnimCollection


VMLegs.PlayAnimFromCollection = function(self, collectionName)
    local collection = self.AnimCollection[collectionName]
    if not collection then
        print(string.format('PlayAnimFromCollection: collection "%s" not found', collectionName))
        return
    end
    
    self:PlayAnim(collection[math.random(#collection)])
end

VManip.PlayAnimFromCollection = VMLegs.PlayAnimFromCollection

author = nil
handModel = nil
legsModel = nil
animname = nil