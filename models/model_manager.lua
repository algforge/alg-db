-- Define the ModelManager class
ModelManager = {}
ModelManager.__index = ModelManager

-- Create a new ModelManager instance
function ModelManager:new()
    local instance = setmetatable({}, self)
    instance.models = {} -- models[adapterName] = {modelClasses}
    instance.adapters = {} -- adapterName to adapter instance
    instance.modelNames = {} -- modelName to modelClass
    return instance
end

-- Initialize the ModelManager with an adapter
function ModelManager:init(adapter)
    self.adapters[adapter.adapterName] = adapter
    self.adapterName = adapter.adapterName
    return self
end

-- Register a model class with the ModelManager
function ModelManager:registerModel(modelClass)
    local adapterName = self.adapterName
    local modelName = modelClass.__name -- Assuming modelClass has a __name property
    
    if not modelName then
        error("No class name was assigned, ensure you're using __name when declaring the class.")
    end

    if not self.models[adapterName] then
        self.models[adapterName] = {}
    end
    
    if not self.modelNames[modelName] then
        self.modelNames[modelName] = modelClass
        table.insert(self.models[adapterName], modelClass)
    else
        error(
            string.format("Model class '%s' is already registered; you cannot register the same class twice.", modelName)
        )
    end
end

-- Check if a model is registered
function ModelManager:isModelRegistered(modelClass)
    local adapterName = self.adapterName
    local modelName = modelClass.__name -- Assuming modelClass has a __name property

    if self.models[adapterName] then
        for _, registeredClass in ipairs(self.models[adapterName]) do
            if registeredClass.__name == modelName then
                return true
            end
        end
    end

    return false
end

function ModelManager:getModelInstanceByClass(modelClass)
    local adapterName = self.adapterName
    local modelName = modelClass.__name -- Assuming modelClass has a __name property

    if self.models[adapterName] then
        for _, registeredClass in ipairs(self.models[adapterName]) do
            if registeredClass.__name == modelName then
                return registeredClass
            end
        end
    end

    return nil
end

-- Sets up all models by initializing instances, resolving dependencies, and creating tables in the correct order.
function ModelManager:setupAllModels()
    local initializedModels = {} -- Stores initialized model instances
    local modelClassToInstance = {} -- Maps model classes to their instances
    local modelDependencies = {} -- Tracks model dependencies
    local modelOrder = {} -- Stores the order in which models should be created

    -- Initialize all models and store instances
    for adapterName, models in pairs(self.models) do
        for _, modelClass in ipairs(models) do
            local success, instance = pcall(function()
                return modelClass:new(self.adapters[adapterName])
            end)

            if not success or not instance then
                error(string.format("Error initializing %s: %s", modelClass.__name or "unknown", instance))
            end

            -- Store instance and its class for later reference
            modelClassToInstance[modelClass] = instance
            initializedModels[modelClass.__name] = instance
        end
    end

    -- Ensure related models are correctly referenced and track dependencies
    for modelName, instance in pairs(initializedModels) do
        for fieldName, field in pairs(instance.fields) do
            if field.type == "ManyToMany" or field.type == "ForeignKey" and field.relatedModel then
                local relatedModel = field.relatedModel
                local relatedInstance = modelClassToInstance[relatedModel]

                if relatedInstance then
                    -- Replace uninitialized relatedModel with the initialized instance
                    field.relatedModel = relatedInstance
                else
                    error(string.format("Related model %s not found for %sField", relatedModel.__name, field.type))
                end

                -- Track dependencies
                modelDependencies[modelName] = modelDependencies[modelName] or {}
                modelDependencies[modelName][relatedModel.__name] = true
            end
        end
    end

    -- Function to resolve the creation order based on dependencies
    local function resolveOrder(modelName, visited, stack)
        if visited[modelName] then return end
        visited[modelName] = true
        local dependencies = modelDependencies[modelName] or {}
        for depModelName in pairs(dependencies) do
            resolveOrder(depModelName, visited, stack)
        end
        table.insert(stack, modelName)
    end

    -- Resolve creation order so when we create the tables we do it in the correct order
    local visited = {}
    local stack = {}
    for modelName in pairs(initializedModels) do
        resolveOrder(modelName, visited, stack)
    end

    -- Create tables for all models in the correct order
    for _, modelName in ipairs(stack) do
        local instance = initializedModels[modelName]
        if instance then
            instance:createTable()
        end
    end
end

-- Retrieve the singleton instance
function ModelManager:getInstance()
    if not self.instance then
        self.instance = self:new()
    end
    return self.instance
end

return ModelManager
