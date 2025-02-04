--[[ 
    MySQLAsyncMock Module

    Description:
        This module provides a mock implementation for asynchronous MySQL operations 
        using HTTP requests. It is designed for testing purposes (without running via FiveM) and simulates 
        interactions with a MySQL database by sending requests to a local server.

    Features:
        - Fetch all records from a database table.
        - Insert a new record into a database table.
        - Execute arbitrary SQL commands.
        - Fetch a single scalar value from the database.

    Usage:
        The functions in this module accept SQL queries and parameters, and they 
        utilize callbacks to handle responses asynchronously. The module uses 
        JSON for data interchange.

    Note:
        This module should only be used in testing environments. For production 
        use, please implement actual database connections.

    Dependencies:
        - dkjson (for JSON encoding/decoding)

    Example:
        MySQLAsyncMock.fetchAll("SELECT * FROM users", {}, function(results, err)
            if err then
                print("Error:", err)
            else
                print("Fetched records:", results)
            end
        end)
]]

MySQLAsyncMock = {}
-- Remove this for non-testing purposes
MySQLAsyncMock.Async = MySQLAsyncMock

local json = require('dkjson')

local function http_request(method, url, body)
    local command = string.format('curl -X %s -H "Content-Type: application/json" -d "%s" %s', method, body:gsub('"', '\\"'), url)
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    return result
end

function MySQLAsyncMock.fetchAll(query, params, callback)
    local json_body = string.format('{"query":"%s","params":%s}', query, json.encode(params))
    local response = http_request('POST', 'http://localhost:3000/fetchAll', json_body)
    
    -- Debug print response
    print("Response from server:", response)

    -- Decode JSON response
    local results, pos, err = json.decode(response)

    if err then
        print("Error decoding JSON:", err)
        callback(nil, err)
    else
        -- Call the provided callback with the parsed results and no error
        callback(results, nil)
    end
end

function MySQLAsyncMock.insert(query, params, callback)
    local json_body = string.format('{"query":"%s","params":%s}', query, json.encode(params))
    local response = http_request('POST', 'http://localhost:3000/insert', json_body)
    
    -- Debug print response
    print("Response from server:", response)

    -- Decode JSON response
    local results, pos, err = json.decode(response)
    local insertId = results.insertId
    
    -- Handle the case where conversion might fail
    if insertId == nil then
        callback(nil, "Invalid insertId")
    else
        callback(insertId, nil)
    end
end

function MySQLAsyncMock.execute(query, params, callback)
    local json_body = string.format('{"query":"%s","params":%s}', query, json.encode(params))
    local response = http_request('POST', 'http://localhost:3000/execute', json_body)

    -- Print response for debugging
    print("Response from server:", response)

    -- Decode JSON response
    local results, pos, err = json.decode(response)
    
    if err then
        print("Error decoding JSON:", err)
        callback(nil, err)
    else
        callback(results.affectedRows, nil)
    end
end

function MySQLAsyncMock.fetchScalar(query, params, callback)
    local json_body = string.format('{"query":"%s","params":%s}', query, json.encode(params))
    local response = http_request('POST', 'http://localhost:3000/fetchScalar', json_body)

    -- Print response for debugging
    print("Response from server:", response)

    -- Decode JSON response
    local results, pos, err = json.decode(response)
    
    if err then
        print("Error decoding JSON:", err)
        callback(nil, err)
    else
        callback(results.scalar, nil)
    end
end

return MySQLAsyncMock
