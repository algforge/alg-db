Adapter = {}
Adapter.__index = Adapter


function Adapter:createTable(model)
    error("createTable method not implemented")
end

function Adapter:generateColumnDefinition(fieldName, field)
    error("generateColumnDefinition method not implemented")
end

function Adapter:insert(tableName, data)
    error("insert method not implemented")
end

function Adapter:update(tableName, conditions, data)
    error("update method not implemented")
end

function Adapter:delete(tableName, conditions, callback)
    error("delete method not implemented")
end

function Adapter:find(tableName, id, callback)
    error("find method not implemented")
end

function Adapter:seed(tableName, data)
    error("seed method not implemented")
end

function Adapter:filter(tableName, conditions)
    error("filter method not implemented")
end

function Adapter:order(query, order_by)
    error("order method not implemented")
end

function Adapter:limit(query, limit)
    error("limit method not implemented")
end

function Adapter:offset(query, offset)
    error("offset method not implemented")
end

function Adapter:union(query1, query2)
    error("union method not implemented")
end

function Adapter:createQuerySet(tableName)
    error("createQuerySet method not implemented")
end

function Adapter:beginTransaction(callback)
    error("beginTransaction method not implemented")
end

function Adapter:commitTransaction(callback)
    error("commitTransaction method not implemented")
end

function Adapter:rollbackTransaction(callback)
    error("rollbackTransaction method not implemented")
end

function Adapter:execute(query, callback)
    error("execute method not implemented")
end

return Adapter
