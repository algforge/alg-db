-- This module provides the QuerySet class, which represents a query builder for database operations.

local ResultProcessor = require("result_processor")
local Q = require("Q")

local QuerySet = {}
QuerySet.__index = QuerySet


-- Represents a query set for a specific model.
-- @param model The model object for which the query set is created.
-- @return The QuerySet object.
function QuerySet:new(model)
    local self = setmetatable({}, self)
    self.adapter = model.adapter
    self.tableName = model.tableName
    self.model = model
    self.columns = {}
    self.conditions = {}
    self.joins = {}
    self.order_by_val = nil
    self.limit_val = nil
    self.offset_val = nil
    self.union_query = nil
    self.return_as_dict = true  -- Default to returning results as dictionaries
    return self
end

function QuerySet:addJoin(relatedModel, fieldName)
    -- Collect join information to be used
    local joinDetails = {
        relatedModel = relatedModel,
        fieldName = fieldName,
        primaryKey = self.model:getPrimaryKeyField(),
        relatedPrimaryKey = relatedModel:getPrimaryKeyField(),
    }

    -- Store the join details for the adapter to format when building the query
    table.insert(self.joins, joinDetails)

    -- Return self to allow method chaining
    return self
end

function QuerySet:select_related(...)
    -- Clone the current QuerySet to allow chaining
    local clone = self:clone()

    -- Add related fields to the query structure
    clone._select_related = { ... }

    -- Todo: Handle the case where no specific fields are provided (select all relationships)
    if #clone._select_related == 0 then
        clone._select_related_all = true
    end

    return clone
end

-- Get the fields of the model associated with the QuerySet.
function QuerySet:getFields()
    return self.model.fields
end

-- Retrieves or creates a QuerySet for the given model.
-- @param model The model to create a QuerySet for.
-- @return The QuerySet object associated with the model.
function QuerySet:getOrCreate(model)
    local adapter, tableName = model.adapter, model.tableName
    if not model.adapter.querySets then
        model.adapter.querySets = {}
    end
    if not adapter.querySets[tableName] then
        adapter.querySets[tableName] = QuerySet:new(model)
    end
    return adapter.querySets[tableName]
end

-- Method to specify columns to select and return as dictionaries
-- @param columns (table) The columns to select
-- @return (table) The QuerySet object
function QuerySet:values(columns)
    self.columns = columns
    self.return_as_dict = true
    return self
end

-- Method to specify columns to select and return as a list of tuples
-- @param columns (table) The columns to select
-- @return (table) The QuerySet object
function QuerySet:values_list(columns)
    self.columns = columns
    self.return_as_dict = false
    return self
end

-- Set conditions for filtering
-- @param conditions (table) The conditions for filtering
-- @return (table) The QuerySet object
function QuerySet:filter(conditions)
    self.conditions = self.conditions or {}

    for key, condition in pairs(conditions) do
        if getmetatable(condition) == Q then
            -- Add Q object condition directly
            table.insert(self.conditions, condition:toCondition())
        else
            -- Handle direct field lookup conditions using Q:fromKeyValue
            local qInstance = Q:new(key, condition)
            table.insert(self.conditions, qInstance:fromKeyValue(key, condition))
        end
    end

    return self
end

-- Set the order for the results
-- @param order_by (string) The column to order by
-- @return (table) The QuerySet object
function QuerySet:order(order_by)
    self.order_by_val = order_by
    return self
end

-- Set the limit of results
-- @param limit (number) The maximum number of results to return
-- @return (table) The QuerySet object
function QuerySet:limit(limit)
    self.limit_val = limit
    return self
end

-- Set the offset for the results
-- @param offset (number) The number of results to skip
-- @return (table) The QuerySet object
function QuerySet:offset(offset)
    self.offset_val = offset
    return self
end

-- Union with another QuerySet
-- @param otherQuerySet (table) The QuerySet to union with
-- @return (table) The QuerySet object
function QuerySet:union(otherQuerySet)
    self.union_query = otherQuerySet:buildQuery()
    return self
end

-- Universal method for building a query structure
-- @return (table) The query structure
function QuerySet:buildQuery()
    return {
        tableName = self.tableName,
        columns = self.columns,
        conditions = self.conditions,
        order_by = self.order_by_val,
        limit = self.limit_val,
        offset = self.offset_val,
        union = self.union_query
    }
end

-- Retrieve the results of the query
-- @param callback (function) The callback function to handle the results
function QuerySet:get(callback)
    local queryStruct = self:buildQuery()
    self.adapter:execute_query(queryStruct, function(results, err)
        if err then
            callback(nil, err)
        else
            local processor = ResultProcessor:new(self.return_as_dict, self.columns)
            local processed_results = processor:process(results)
            callback(processed_results, nil)
        end
    end)
end

 -- Create a shallow copy of the current QuerySet object
function QuerySet:clone()
    local clone = {}
    for k, v in pairs(self) do
        clone[k] = v
    end
    setmetatable(clone, getmetatable(self))
    return clone
end

-- Reset the QuerySet to its initial state
-- @return (table) The QuerySet object
function QuerySet:reset()
    self.conditions = {}
    self.columns = {}
    self.joins = {}
    self.order_by_val = nil
    self.limit_val = nil
    self.offset_val = nil
    self.union_query = nil
    return self
end

-- Return the QuerySet module
return QuerySet
