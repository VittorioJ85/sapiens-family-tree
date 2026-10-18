-- Adapted from Hammerstone; original authors SirLich and earmuffs.
-- Keep the original private dependency graph, output array and logger.
-- Native mjrequire inspects module.onload, so helpers must return a table.
local repair = {}
function repair:apply(ddapiManager,entityManagers,sortedObjectLoaders,log)
function ddapiManager:checkAndSortLoaders()
	local dependencies = {}

	for _, entityManager in ipairs(entityManagers) do 
		for objectType, loader in pairs(entityManager.loaders) do 
			loader.manager = entityManager
			dependencies[objectType] = {}

			if loader.dependencies then
				for _, dep in ipairs(loader.dependencies) do 
					if not ddapiManager:getLoaderAndSettings(dep) then
						ddapiManager:raiseError("ERROR. ObjectType ", dep, " does not exist")
					end

					table.insert(dependencies[objectType], dep)
				end
			end
		end
	end

	while next(dependencies) do
		local found = false 

		for objectType, deps in pairs(dependencies) do 
			for i = #deps, 1, -1 do 
				if not dependencies[deps[i]] then
					found = true
					table.remove(deps, i)
				end
			end

			if #deps == 0 then
				-- Removing a root loader also makes progress, regardless of pairs order.
				found = true
				table.insert(sortedObjectLoaders, objectType)
				dependencies[objectType] = nil
			end
		end

		if next(dependencies) and not found then
			ddapiManager:raiseError("ERROR IN DDAPI. Circular dependencies found. These dependencies could not be resolved: ", dependencies)
		end
	end

	log:schema("ddapi", "No circular dependencies found. Here are the sorted loaders: ", sortedObjectLoaders)
end
return ddapiManager.checkAndSortLoaders
end
return repair
