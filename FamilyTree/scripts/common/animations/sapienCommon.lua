local mod={loadOrder=20}
function mod:onload(common)
    local setup=common.setup
    function common:setup(info,...)
        setup(self,info,...)
        local frames=info.animations
        -- Public 0.6.1.3 lacks crouchLow. Select only poses registered by
        -- this skeleton; keep the action and its duration on older releases.
        local stand=frames.stand.keyframes[1][1]
        local seated=frames.sitFocus and frames.sitFocus.keyframes[1][1] or stand
        local crouched=frames.crouchLow and frames.crouchLow.keyframes[1][1] or seated
        -- A non-explicit twelve-second bedside pause on the native skeleton.
        -- Pose-only frames avoid importing tools, audio and particle triggers.
        mj:insertIndexed(frames,{key="ftSpendTimeTogether",keyframes={
            {stand,1},
            {crouched,1.5},
            {seated,2},
            {seated,5},
            {crouched,1.5},
            {stand,1},
        }})
    end
end
return mod
