local Adapter = require("adapter")
local QuerySet = require("QuerySet")
local MySQL = require("mysql_async_mock")


local MySQLAdapter = setmetatable({}, { __index = Adapter })
MySQLAdapter.__index = MySQLAdapter


function MySQLAdapter:new(connection)
    local self = setmetatable({}, self)
    self.connection = connection
    self.adapterName = "mysql"
    return self
end

function MySQLAdapter:execute(query, params, callback)
    -- Execute the query with parameters if provided
    MySQL.Async.execute(query, params, function(results, err)
        if callback then
            callback(results, err)
        end
    end)
end

function MySQLAdapter:createTable(model)
    local tableName = model:getTableName()
    local fields = model.fields

    local columns = {}
    for fieldName, field in pairs(fields) do
        local columnDefinition = self:generateColumnDefinition(fieldName, field)
        if columnDefinition then
            table.insert(columns, columnDefinition)
        end

        -- Handle ForeignKey relationships
        if field.type == "ForeignKey" then
            local relatedTable = field.relatedModel:getTableName()
            local onDelete = field.onDelete
            table.insert(columns, string.format("FOREIGN KEY (%s) REFERENCES %s(%s) ON DELETE %s",
                fieldName, relatedTable, field.relatedModel.primaryKeyField, onDelete))
        end
    end

    local query = string.format("CREATE TABLE IF NOT EXISTS %s (%s)", tableName, table.concat(columns, ", "))
    self:execute(query)

    -- Handle ManyToMany relationships by creating join tables
    for fieldName, field in pairs(fields) do
        if field.type == "ManyToMany" then
            local relatedTable = field.relatedModel:getTableName()
            local joinTableName = string.format("%s_%s", tableName, relatedTable)
            local joinTableColumns = {
                string.format("%s_id INT, FOREIGN KEY (%s_id) REFERENCES %s(%s) ON DELETE CASCADE",
                    tableName, tableName, tableName, model.primaryKeyField),
                string.format("%s_id INT, FOREIGN KEY (%s_id) REFERENCES %s(%s) ON DELETE CASCADE",
                    relatedTable, relatedTable, relatedTable, field.relatedModel.primaryKeyField)
            }
            local joinTableQuery = string.format("CREATE TABLE IF NOT EXISTS %s (%s)", joinTableName, table.concat(joinTableColumns, ", "))
            self:execute(joinTableQuery)
        end
    end
end

function MySQLAdapter:generateColumnDefinition(fieldName, field)
    local sqlType
    if field.type == "Integer" then
        sqlType = "INT"
    elseif field.type == "Float" then
        sqlType = "FLOAT"
    elseif field.type == "Char" then
        sqlType = "VARCHAR(" .. field.options.max_length .. ")"
    elseif field.type == "Text" then
        sqlType = "TEXT"
    elseif field.type == "Date" then
        sqlType = "DATE"
    elseif field.type == "ForeignKey" then
        sqlType = "INT"  -- Assuming foreign keys are represented as integers
    elseif field.type == "ManyToMany" then
        -- ManyToMany relationships require a separate join table, so skip column generation
        return nil
    end

    local columnDefinition = fieldName .. " " .. sqlType
    if field.options.auto_increment then
        columnDefinition = columnDefinition .. " AUTO_INCREMENT"
    end
    if field.options.primary_key then
        columnDefinition = columnDefinition .. " PRIMARY KEY"
    end

    return columnDefinition
end

function MySQLAdapter:generateParameterValues(data, bWantsColumns, bForUpdate)
    local values = {}
    local params = {}
    local columns = {}

    for k, v in pairs(data) do
        if bForUpdate then
            -- For UPDATE statements, format as column_name=?
            table.insert(values, string.format("%s=?", k))
        else
            -- For INSERT statements, format as ?
            table.insert(values, "?")
        end
        table.insert(params, v)
        if bWantsColumns then
            table.insert(columns, k)
        end
    end

    if bForUpdate then
        return table.concat(values, ", "), params
    elseif bWantsColumns then
        return table.concat(values, ", "), params, table.concat(columns, ", ")
    else
        return table.concat(values, ", "), params
    end
end


-- Generates a condition string and parameter list for a given set of conditions
-- @param conditions (table) - The conditions to generate the query for
-- @return conditionString (string) - The generated condition string
-- @return params (table) - The generated parameter list
function MySQLAdapter:generateConditionString(conditions)
    local conditionStrings = {}
    local params = {}

    -- Lookup table for SQL operations
    local operationMappings = {
        contains = function(field) return string.format("%s LIKE ?", field), "%%%s%%" end,
        icontains = function(field) return string.format("LOWER(%s) LIKE LOWER(?)", field), "%%%s%%" end,
        exact = function(field) return string.format("%s = ?", field), "%s" end,
        year = function(field) return string.format("YEAR(%s) = ?", field), "%s" end,
        lte = function(field) return string.format("%s <= ?", field), "%s" end,
        gte = function(field) return string.format("%s >= ?", field), "%s" end,
        lt = function(field) return string.format("%s < ?", field), "%s" end,
        gt = function(field) return string.format("%s > ?", field), "%s" end,
        startswith = function(field) return string.format("%s LIKE ?", field), "%s%%" end,
        endswith = function(field) return string.format("%s LIKE ?", field), "%%%s" end,
    }

    local function processCondition(cond)
        local field = cond.field
        local operation = cond.operation or "exact"
        local value = cond.value
        local queryPart, format = operationMappings[operation](field)
        table.insert(params, format:format(value))
        
        local conditionPart = queryPart

        -- Handle negation
        if cond.negated then
            conditionPart = "NOT (" .. conditionPart .. ")"
        end

        -- Handle OR conditions
        if cond.orCondition then
            local orQueryPart = processCondition(cond.orCondition)
            conditionPart = "(" .. conditionPart .. " OR " .. orQueryPart .. ")"
        end

        -- Handle AND conditions
        if cond.andCondition then
            local andQueryPart = processCondition(cond.andCondition)
            conditionPart = "(" .. conditionPart .. " AND " .. andQueryPart .. ")"
        end

        return conditionPart
    end

    if #conditions == 0 then
        conditions = {conditions}
    end
    
    -- Iterate over conditions
    for _, condition in ipairs(conditions) do
        local conditionPart = processCondition(condition)
        table.insert(conditionStrings, conditionPart)
    end

    return table.concat(conditionStrings, " AND "), params
end

--- Updates records in a MySQL table based on specified conditions.
-- @param tableName The name of the table to update.
-- @param conditions A table specifying the conditions for the update.
-- @param data A table containing the data to update.
-- @param callback An optional callback function to be called after the update is executed.
function MySQLAdapter:update(tableName, conditions, data, callback)
    local updates, updateParams = self:generateParameterValues(data, false, true)
    local condition_strs, conditionParams = self:generateConditionString(conditions)

    local params = {}
    table.move(updateParams, 1, #updateParams, 1, params)
    table.move(conditionParams, 1, #conditionParams, #updateParams + 1, params)

    local query = string.format("UPDATE %s SET %s WHERE %s", tableName, updates, condition_strs)
    self:execute(query, params, callback)
end

function MySQLAdapter:insert(tableName, data, callback)
    -- Generate parameter values for the INSERT statement
    local values, params, columns = self:generateParameterValues(data, true)

    -- Construct the INSERT query
    local query = string.format("INSERT INTO %s (%s) VALUES (%s)", tableName, columns, values)

    -- Execute the query and handle the result
    MySQL.Async.insert(query, params, function(result, err)
        if callback then
            callback(result, err)
        end
    end)
end

function MySQLAdapter:delete(tableName, conditions, callback)
    local condition_strs, params = self:generateParameterValues(conditions, false)

    if #condition_strs == 0 then
        error("No conditions specified for deletion.")
    end

    local query = string.format("DELETE FROM %s WHERE %s", tableName, condition_strs)
    self:execute(query, params, callback)
end

function MySQLAdapter:find(tableName, id, callback)
    local query = string.format("SELECT * FROM %s WHERE id=?", tableName)
    MySQL.Async.fetchAll(query, { id }, function(results, err)
        if callback then
            callback(results, err)
        end
    end)
end

function MySQLAdapter:seed(tableName, data)
    for _, row in ipairs(data) do
        self:insert(tableName, row)
    end
end

function MySQLAdapter:filter(tableName, conditions)
    local condition_strs, params = self:generateConditionString(conditions)
    local query = string.format("SELECT * FROM %s WHERE %s", tableName, condition_strs)
    return query, params
end

function MySQLAdapter:order(query, order_by)
    query = query .. string.format(" ORDER BY %s", order_by)
    return query
end

function MySQLAdapter:limit(query, limit)
    query = query .. string.format(" LIMIT %d", limit)
    return query
end

-- Adds an offset to the given query
-- @param query (string) - The original query
-- @param offset (number) - The offset value
-- @return (string) - The modified query with the offset
function MySQLAdapter:offset(query, offset)
    query = query .. string.format(" OFFSET %d", offset)
    return query
end

-- Combines two queries using the UNION operator
-- @param query1 (string) - The first query
-- @param query2 (string) - The second query
-- @return (string) - The combined query using UNION
function MySQLAdapter:union(query1, query2)
    local union_query = string.format("%s UNION %s", query1, query2)
    return union_query
end

-- Executes a query and invokes the provided callback function with the result
-- @param queryStruct (table) - The query structure containing the table name, columns, conditions, etc.
-- @param callback (function) - The callback function to be invoked with the query result
function MySQLAdapter:execute_query(queryStruct, callback)
    local columns = #queryStruct.columns > 0 and table.concat(queryStruct.columns, ", ") or "*"
    local query = string.format("SELECT %s FROM %s", columns, queryStruct.tableName)
    local condition_strs, params = {}, {}

    if next(queryStruct.conditions) then
        condition_strs, params = self:generateConditionString(queryStruct.conditions)
        query = query .. " WHERE " .. condition_strs
    end

    if queryStruct.order_by then
        query = query .. string.format(" ORDER BY %s", queryStruct.order_by)
    end

    if queryStruct.limit then
        query = query .. " LIMIT " .. queryStruct.limit
    end

    if queryStruct.offset then
        query = query .. " OFFSET " .. queryStruct.offset
    end
    
    if queryStruct.union then
        query = string.format("%s UNION %s", query, queryStruct.union)
    end

    self:async_execute_query(query, params, callback)
end

function MySQLAdapter:beginTransaction(callback)
    self:execute("START TRANSACTION", {}, function(success, err)
        if not success then
            callback(nil, err)
        else
            callback(true)
        end
    end)
end

function MySQLAdapter:commitTransaction(callback)
    self:execute("COMMIT", {}, function(success, err)
        if not success then
            callback(nil, err)
        else
            callback(true)
        end
    end)
end

function MySQLAdapter:rollbackTransaction(callback)
    self:execute("ROLLBACK", {}, function(success, err)
        if not success then
            callback(nil, err)
        else
            callback(true)
        end
    end)
end

function MySQLAdapter:async_execute_query(query, params, callback)
    -- Perform the query and then call the callback with results and error
    MySQL.Async.fetchAll(query, params, function(results, err)
        callback(results, err)
    end, function(err)
        callback(nil, err)
    end)
end

function MySQLAdapter:handleForeignKey(tableName, fieldName, entityId, relatedInstance)
    local relatedId = relatedInstance:getPrimaryKeyValue()
    if not relatedId then
        relatedInstance:save()
        relatedId = relatedInstance:getPrimaryKeyValue()
    end

    -- Update the foreign key field in the main table
    local query = string.format("UPDATE %s SET %s = ? WHERE id = ?", tableName, fieldName)
    self:execute(query, { relatedId, entityId })
end

function MySQLAdapter:handleManyToMany(modelInstance, fieldName, entityId, relatedInstances)
    -- Use the getRelatedTableName method from the BaseModel
    local relatedTable = modelInstance:getRelatedTableName(fieldName)
    local joinTable = string.format("%s_%s", modelInstance.tableName, relatedTable)

    -- Delete existing relationships
    self:execute(string.format("DELETE FROM %s WHERE %s_id = ?", joinTable, modelInstance.tableName), { entityId })

    -- Insert new relationships
    for _, relatedInstance in ipairs(relatedInstances) do
        local relatedId = relatedInstance:getPrimaryKeyValue()
        if not relatedId then
            relatedInstance:save()
            relatedId = relatedInstance:getPrimaryKeyValue()
        end
        self:execute(string.format("INSERT INTO %s (%s_id, %s_id) VALUES (?, ?)", joinTable, modelInstance.tableName, relatedTable), { entityId, relatedId })
    end
end

return MySQLAdapter
