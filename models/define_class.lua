local BaseModel = require("base_model")

-- Cache for storing methods
local methodCache = {}


-- DefineClass function to streamline model creation
function DefineClass(name, adapter, tableNameOrSetupFn, setupMethodFn)
    -- Create a new model class
    local class = setmetatable({}, BaseModel)
    class.__index = class
    class.__name = name

    -- Determine table name based on whether tableNameOrSetupFn is a string or function
    if type(tableNameOrSetupFn) == "string" then
        class.__tableName = tableNameOrSetupFn
    else
        class.__tableName = name:lower() .. "s" -- Default table name if not specified
        setupMethodFn = tableNameOrSetupFn -- Assign function to setupMethodFn
    end

    -- Initialize class-level properties
    class:initializeClassProperties(adapter, class.__tableName)

    -- Run the setup method if provided
    if setupMethodFn and type(setupMethodFn) == "function" then
        setupMethodFn(class)
    end

    -- Initialize the queryset class, needed for .objects property and query methods
    class:initializeQueryset()

    -- Cache the class methods
    methodCache[class] = {}
    local mt = getmetatable(class)
    while mt do
        for key, value in pairs(mt) do
            if type(value) == "function" then
                methodCache[class][key] = value
            end
        end
        mt = getmetatable(mt)
    end

    -- Super method to retrieve and call superclass methods from cache
    function class:Super(methodName, ...)
        local cachedMethods = methodCache[getmetatable(self)]
        local method = cachedMethods and cachedMethods[methodName]
        if method then
            return method(self, ...)
        else
            error(string.format("Method '%s' not found in superclass chain.", methodName))
        end
    end

    return class
end

return DefineClass
