-- The Q class represents a query condition in a database query.
-- It allows constructing complex conditions using logical operators like OR and AND.
Q = {}
Q.__index = Q

-- Creates a new instance of the Q class.
-- @param field (string) The field name for the condition.
-- @param value (any) The value to compare against the field.
-- @return instance (table) The newly created Q instance.
function Q:new(field, value)
    local instance = setmetatable({}, Q)
    instance.field = field
    instance.value = value
    instance.operation = "exact"
    return instance
end

-- Adds an OR condition to the current Q instance.
-- @param other (table) The Q instance representing the OR condition.
-- @return self (table) The updated Q instance.
function Q:OR(other)
    self.orCondition = other
    return self
end

-- Adds an AND condition to the current Q instance.
-- @param other (table) The Q instance representing the AND condition.
-- @return self (table) The updated Q instance.
function Q:AND(other)
    self.andCondition = other
    return self
end

-- Negates the current Q instance.
-- @return self (table) The updated Q instance.
function Q:NOT()
    self.isNegated = true
    return self
end

-- Converts the Q object to a condition table.
-- @return conditionTable (table) The condition table representing the Q object.
function Q:toCondition()
    -- Parses the condition object recursively
    local function parseCondition(cond)
        local parts = {}
        -- Splits the field string using the "__" delimiter
        for part in string.gmatch(cond.field, "([^__]+)") do
            table.insert(parts, part)
        end

        local operation = parts[2] or "exact"
        local conditionPart = {
            field = parts[1],
            operation = operation,
            value = cond.value
        }

        if cond.isNegated then
            conditionPart.negated = true
        end

        if cond.orCondition then
            -- Recursively parses the OR condition
            conditionPart.orCondition = parseCondition(cond.orCondition)
        end

        if cond.andCondition then
            -- Recursively parses the AND condition
            conditionPart.andCondition = parseCondition(cond.andCondition)
        end

        return conditionPart
    end

    -- Returns the condition table representing the Q object
    return parseCondition(self)
end

-- Creates a new instance of the Q class from a key-value pair.
-- @param key (string) The key to extract the field and operation from.
-- @param value (any) The value to assign to the Q instance.
-- @return self (table) The Q instance.
function Q:fromKeyValue(key, value)
    -- Extract the field and operation from the key using a regular expression.
    -- The key is expected to be in the format "field__operation".
    -- If no operation is specified, the default operation is "exact".
    local field, operation = key:match("([^__]+)__?(.*)")
    if operation == "" then operation = "exact" end

    -- Assign the extracted field, operation, and value to the Q instance.
    self.field = field
    self.operation = operation
    self.value = value

    -- Return the Q instance.
    return self
end

return Q
