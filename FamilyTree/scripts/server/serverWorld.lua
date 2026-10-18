local service = mjrequire "familyTree/service"
local mod = {loadOrder = 20}
function mod:onload(world)
    local setBridge = world.setBridge
    function world:setBridge(...)
        service:reset()
        setBridge(self, ...)
        local gom = mjrequire "server/serverGOM"
        -- Retain only loads emitted during this bridge initialization. init clears
        -- old world state, but other adapters may load Sapiens inside setBridge.
        local pending, first, last = service.queue, service.head, service.tail
        service:init(self, gom)
        local conception=mjrequire "familyTree/conception"
        conception:init(service)
        for i = first, last do service:enqueue(gom:getObjectWithID(pending[i])) end
        local server = mjrequire "server/server"
        server:registerNetFunction("familyTreeRequest", function(clientID, request)
            return service:request(clientID, request)
        end)
        server:registerNetFunction("familyTreeConception", function(clientID, request)
            return (mjrequire "familyTree/conception"):request(service,clientID,request)
        end)
    end
    local loaded = world.sapienLoaded
    function world:sapienLoaded(sapien, ...)
        loaded(self, sapien, ...)
        service:enqueue(sapien)
    end
    local update = world.update
    function world:update(...)
        update(self, ...)
        service:drain()
        if service.archive then (mjrequire "familyTree/conception"):update(service) end
    end
end
return mod
