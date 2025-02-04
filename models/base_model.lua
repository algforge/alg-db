local QuerySet = require("QuerySet")
local Q = require("Q")
local Field = require("fields")

BaseModel = {}
BaseModel.__index = BaseModel


-- Static method to initialize class properties like objects and queryset
function BaseModel:initializeClassProperties(adapter, tableName)
    -- Ensure tableName and adapter are set at the class level
    if not tableName then
        error("Table name must be set for the model.")
    end

    if not adapter then
        error("Adapter must be provided.")
    end

    self.adapter = adapter
    self.tableName = tableName
    self.fields = self.fields or {}
end

function BaseModel:initializeQueryset()
    -- Ensure objects (QuerySet) is initialized only once at the class level
    if not self.objects then
        self.objects = QuerySet:getOrCreate(self)
    end
end

function BaseModel:new(tableName, adapter)
    -- Note: Using 'self' as the instance variable
    local self = setmetatable({}, self)

    -- Assign adapter and tableName at the instance level
    -- If not provided, use the class-level values
    self.adapter = adapter or self.adapter
    self.tableName = tableName or self.tableName

    -- Call setupProperties if defined
    if self.setupProperties then
        self:setupProperties(self.tableName)
    end
    
    -- Ensure the class name (__name) is set
    if not self.__name then
        error(string.format("No class name was provided for '%s'; ensure you're using __name for the class.", self.tableName or "unknown"))
    end

    -- Ensure the model is registered with the ModelManager
    local modelManager = ModelManager:getInstance()
    if not modelManager:isModelRegistered(self) then
        error(string.format("Model with name '%s' is not registered with ModelManager.", self.__name or "unknown"))
    end

    -- Call setupModel if defined
    if self.setupModel then
        self:setupModel()
    end

    return self
end

function BaseModel:setupProperties(tableName)
    -- Instance-level properties
    self.tableName = tableName or self.tableName
    self.fields = self.fields or {}
    self.query = nil
    self.primaryKeyField = self.primaryKeyField or 'id' -- Default to 'id' if not provided

    -- Used to exclude all the class properties
    self.excluded_keys = {
        ["tableName"] = true,
        ["fields"] = true,
        ["adapter"] = true,
        ["queryset"] = true,
        ["query"] = true,
        ["objects"] = true,
        ["_cachedAttributes"] = true,
        ["_changes"] = true,
        ["excluded_keys"] = true,
        ["primaryKeyField"] = true
    }

    return self
end

function BaseModel:setupModel()
    -- A function users can override to setup the model fields.
end

function BaseModel:IntegerField(fieldName, options)
    local field = Field.IntegerField:new(options)
    self:addField(fieldName, field)
    return field
end

function BaseModel:CharField(fieldName, options)
    local field = Field.CharField:new(options)
    self:addField(fieldName, field)
    return field
end

function BaseModel:TextField(fieldName, options)
    local field = Field.TextField:new(options)
    self:addField(fieldName, field)
    return field
end

function BaseModel:DateField(fieldName, options)
    local field = Field.DateField:new(options)
    self:addField(fieldName, field)
    return field
end

function BaseModel:ForeignKeyField(fieldName, relatedModel, options)
    local field = Field.ForeignKeyField:new(relatedModel, options)
    self:addField(fieldName, field)
    return field
end

function BaseModel:ManyToManyField(fieldName, relatedModel)
    local field = Field.ManyToManyField:new(relatedModel:setupProperties(relatedModel.__tableName))
    self:addField(fieldName, field)
    return field
end

-- Update the `addField` method to handle dynamic field names and primary key setup
function BaseModel:addField(fieldName, field)
    self.fields[fieldName] = field

    -- Setup the assigned primary key field for later usage.
    local options = field.options or {}
    if options.primary_key then
        self.primaryKeyField = fieldName
    end
end

function BaseModel:getPrimaryKeyField()
    -- Return the name of the primary key field
    return self.primaryKeyField
end

function BaseModel:getPrimaryKeyValue()
    -- Return the value of the primary key field
    return self[self.primaryKeyField]
end

function BaseModel:getForeignKey(fieldName)
    local field = self.fields[fieldName]
    if field and field.type == "ForeignKey" then
        -- Returns the field name in the related model
        return field.relatedModel:getPrimaryKeyField()
    else
        error("No foreign key found for field: " .. fieldName)
    end
end

function BaseModel:isRelationshipField(fieldName)
    local field = self.fields[fieldName]
    return field and field.relatedModel ~= nil
end

-- This method helps gather related model information and construct joins
-- Returns the updated query object with the related fields joined
function BaseModel:buildSelectRelatedQuery(query, relatedFields)
    for _, fieldName in ipairs(relatedFields) do
        local field = self.fields[fieldName]

        if field and field.relatedModel then
            -- Build SQL join statements for the related models
            query:addJoin(field.relatedModel, fieldName)
        end
    end

    return query
end

-- Cache attributes that are not excluded
function BaseModel:cacheAttributes()
    self._cachedAttributes = {}
    for k, v in pairs(self) do
        -- Direct check for exclusion, including relationships
        if not self.excluded_keys[k] and not self:isRelationshipField(k) then
            self._cachedAttributes[k] = v
        end
    end
end

function BaseModel:getAttributes()
    self:cacheAttributes()
    return self._cachedAttributes
end

function BaseModel:handleUpdateCompletion(result, err)
    if err then
        print("Error updating data: " .. err)
    else
        if result then
            local affectedRows = tonumber(result)
            if affectedRows and affectedRows > 0 then
                print("Data updated successfully, rows affected: " .. affectedRows)
            else
                if not err then
                    print("No rows were affected.")
                else
                    print("Update failed.")
                end
            end
        else
            print("No result provided for update!")
        end
    end
end

-- Callback for handling inserts
function BaseModel:handleInsertCompletion(result, err)
    if err then
        print("Error inserting data: " .. err)
    else
        if type(result) == "number" and result > 0 then
            -- Get the primary key field for this model
            local primaryKeyField = self:getPrimaryKeyField()

            -- Assuming result is an insertId or similar
            self[primaryKeyField] = result
            
            print("Data inserted successfully, insertId: " .. tostring(self[primaryKeyField]))
        else
            print("No result provided for insert!")
        end
    end
end

-- Saves the data to the database table without transaction handling.
-- If data is provided, it uses that data for saving, otherwise it uses the instance attributes.
-- If the data has an ID, it performs an update, otherwise it performs an insert.
-- Calls the provided callback function with the result and error, if any.
function BaseModel:save(data, callback)
    -- Use provided data or fetch attributes from the instance
    local save_data = data or self:getAttributes()
    local primaryKeyField = self:getPrimaryKeyField()

    -- Extract relationship data
    local relationshipData = {}
    for fieldName, field in pairs(self.fields or {}) do
        if self:isRelationshipField(fieldName) then
            relationshipData[fieldName] = self[fieldName]
            save_data[fieldName] = nil  -- Ensure relationships aren't passed to insert/update
        end
    end

    local function onOperationComplete(result, err)
        if not err then 
            if save_data[primaryKeyField] then
                -- This was an update operation, handle accordingly
                self:handleUpdateCompletion(result, err)
            else
                -- This was an insert operation, assign the generated ID to the instance
                self:handleInsertCompletion(result, err)
            end

            -- Handle relationships after the main save operation
            self:handleRelationships(self[primaryKeyField], relationshipData, function(relResult, relErr)
                if callback then
                    callback(result, relErr or err)
                end
            end)
        else
            -- Handle any errors from the insert/update operation
            if callback then
                callback(nil, err)
            end
        end
    end

    -- Determine whether to perform an insert or update
    if save_data[primaryKeyField] then
        -- Update operation
        self.adapter:update(self.tableName, Q:new(primaryKeyField, save_data[primaryKeyField]), save_data, onOperationComplete)
    else
        -- Insert operation
        self.adapter:insert(self.tableName, save_data, onOperationComplete)
    end
end

function BaseModel:getRelatedTableName(fieldName)
    local field = self.fields[fieldName]
    if field and field.relatedModel then
        -- Assuming that relatedModel is a model class with a `tableName` property
        return field.relatedModel.tableName
    else
        error("Related model not found for field: " .. fieldName)
    end
end

function BaseModel:handleRelationships(entityId, relationshipData, callback)
    if not next(relationshipData) then
        if callback then callback(true) end
        return
    end

    for fieldName, relatedInstances in pairs(relationshipData) do
        local field = self.fields[fieldName]
        if field.type == "ForeignKey" then
            self.adapter:handleForeignKey(self.tableName, fieldName, entityId, relatedInstances)
        elseif field.type == "ManyToMany" then
            self.adapter:handleManyToMany(self, fieldName, entityId, relatedInstances)
        end
    end

    if callback then
        callback(true)
    end
end

function BaseModel:beginTransaction(callback)
    self.adapter:beginTransaction(callback)
end

function BaseModel:commitTransaction(callback)
    self.adapter:commitTransaction(callback)
end

function BaseModel:rollbackTransaction(callback)
    self.adapter:rollbackTransaction(callback)
end

function BaseModel:delete(conditions, callback)
    -- If conditions are not provided, default to an empty table
    conditions = conditions or {}
    
    -- Ensure there's at least one condition to avoid accidental full table deletes
    if next(conditions) == nil then
        error("No conditions provided for deletion. Specify conditions to avoid deleting the entire table.")
    end

    -- Perform the delete operation with the provided conditions
    self.adapter:delete(self.tableName, conditions, callback)
end

function BaseModel:find(id, callback)
    self.adapter:find(self.tableName, id, callback)
end

function BaseModel:getTableName()
    -- Return the table name derived from the model name or explicitly set
    return self.tableName
end

function BaseModel:createTable()
    self.adapter:createTable(self)
end

function BaseModel:seed(data)
    self.adapter:seed(self.tableName, data)
end

function BaseModel:filter(conditions)
    self.queryset:filter(conditions)
    return self
end

function BaseModel:order(order_by)
    self.queryset:order(order_by)
    return self
end

function BaseModel:limit(limit)
    self.queryset:limit(limit)
    return self
end

function BaseModel:offset(offset)
    self.queryset:offset(offset)
    return self
end

function BaseModel:union(otherModel)
    self.queryset = self.queryset:union(otherModel.queryset)
    return self
end

function BaseModel:first(callback)
    self:limit(1)
    self:get(function(results, err)
        if err then
            callback(nil, err)
        else
            if #results > 0 then
                callback(results[1], nil)
            else
                callback(nil, nil)
            end
        end
    end)
end

function BaseModel:resetQueryset()
    self.queryset = self.queryset:reset()
end

function BaseModel:get(callback)
    self.objects:get(function(results, err)
        self:resetQueryset()
        callback(results, err)
    end)
end

function BaseModel:execute(callback)
    self.queryset:get(function(results)
        self:resetQueryset()
        callback(results)
    end)
end

return BaseModel
