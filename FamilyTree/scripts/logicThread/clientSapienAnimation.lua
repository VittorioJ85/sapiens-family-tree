local mod={loadOrder=20}
function mod:onload(animation)
    local init=animation.init
    function animation:init(...)
        local sequence=(mjrequire "common/actionSequence").types.ftTryForBaby
        local actions=(mjrequire "common/action").types
        -- Native land animation selection cannot handle unknown action IDs.
        -- Change only this client VM's stationary action mapping; server timing
        -- and replicated sequence/progress IDs remain custom and unchanged.
        sequence.actions={actions.moveTo.index,actions.idle.index,actions.idle.index}
        return init(self,...)
    end
end
return mod
