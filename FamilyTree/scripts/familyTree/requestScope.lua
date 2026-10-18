-- One in-flight panel request. Cancellation invalidates late/duplicate replies;
-- it does not cancel a server-side write or imply that a timed-out save failed.
local logic = mjrequire "mainThread/logicInterface"
local timer = mjrequire "common/timer"
local scope = {}
function scope.cancel(owner)
    if owner.cancelRequest then owner.cancelRequest(); owner.cancelRequest=nil end
end
function scope.call(owner, request, callback)
    scope.cancel(owner)
    local done, timeout = false, nil
    local function cancel()
        if done then return end
        done=true
        if timeout then timer:removeTimer(timeout); timeout=nil end
        owner.cancelRequest=nil
    end
    owner.cancelRequest=cancel
    local function complete(data)
        if done then return end
        cancel()
        callback(data)
    end
    timeout=timer:addCallbackTimer(10,function()
        complete({error="No server response. Please reload.",timedOut=true})
    end)
    logic:callServerFunction("familyTreeRequest",request,complete)
end
return scope
