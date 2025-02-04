-- Set package.path to include the directory where the adapter is located
package.path = package.path .. ";./vendor/dkjson/?.lua;./adapters/?.lua;./library/?.lua;./models/?.lua;../?.lua"
-- Set package.cpath to include the directory for DLLs if needed
package.cpath = package.cpath .. ";./adapters/?.dll"

local Adapter = require("Adapter")
local QuerySet = require("QuerySet")
local BaseModel = require("base_model")
local MySQLAdapter = require("mysql_adapter")
ModelManager = require("model_manager")
local Q = require("Q")
local DefineClass = require("define_class")

local connection = {}  -- Assume a valid MySQL connection
local mysqlAdapter = MySQLAdapter:new(connection)

--local Phone = DefineClass("Phone", mysqlAdapter)

local Phone = DefineClass("Phone", mysqlAdapter, function(class)
    -- Define fields for the Phone model
    class:IntegerField("id", { auto_increment = true, primary_key = true })
    class:CharField("number", { max_length = 15 })
    class:CharField("type", { max_length = 50 })
    -- Any additional setup
end)

function Phone:new()
    local instance = BaseModel.new(self, "phones", mysqlAdapter)
    return instance
end

function Phone:setupModel()
    print("Phone:setupModel was called")

    -- Call the superclass (BaseModel) setupModel method
    BaseModel.setupModel(self)
end

-- Declare the User class
local User = DefineClass("User", mysqlAdapter, function(class)
    -- Define fields for the User model

    -- Add the id field with auto-increment and primary key constraints
    class:IntegerField("id", { auto_increment = true, primary_key = true })
    class:CharField("name", { max_length = 255 })
    class:IntegerField("age")
    class:CharField("email", { max_length = 255 })

    -- Add a many-to-many relationship with the Phone model
    class:ManyToManyField("phones", Phone)
end)

function User:new()
    local instance = BaseModel.new(self, "users", mysqlAdapter)
    return instance
end

function User:setupModel()
    print("User:setupModel was called")
    -- Call the superclass (BaseModel) setupModel method
    self:Super('setupModel')
end

local modelManager = ModelManager:getInstance()
modelManager:init(mysqlAdapter)

-- Register models appropriately
modelManager:registerModel(User)
modelManager:registerModel(Phone)

-- Setup all registered models so the tables get created
modelManager:setupAllModels()

-- Get the instance
local userInstance = User:new()

-- Create the users table
--userInstance:createTable()

-- Get the instance
-- Create and save phone entries
local phones = {
    { number = '810-855-2076', type = 'Home Number' },
    { number = '810-855-2077', type = 'Work Number' },
    { number = '810-855-2078', type = 'Mobile Number' },
    { number = '810-855-2079', type = 'Fax Number' },
    { number = '810-855-2080', type = 'Emergency Number' }
}

local phoneInstances = {}
for _, details in ipairs(phones) do
    local phone = Phone:new()
    phone.number = details.number
    phone.type = details.type
    phone:save()
    table.insert(phoneInstances, phone)
end

-- Associate phones
-- Insert a new user
userInstance.name = 'Markiplier'
userInstance.age = 59
--userInstance.id = 1
userInstance.phones = phoneInstances
userInstance:save()

-- Create the phones table
--phoneInstance:createTable()

-- Define the User:save method
function User:save(data, callback)
    -- Optionally process or validate data specific to User
    -- For example, you could add some user-specific logic here

    print('Called User:save!')

    -- Call the superclass (BaseModel) save method
    BaseModel.save(self, data, callback)
end

userInstance.name = "Albert"

userInstance:save()

local userInstanceMarki = User:new()
userInstanceMarki.name = 'Markiplier2'
userInstanceMarki.age = 59
--userInstance.id = 1

userInstanceMarki:save()

-- Define a callback function to handle the result
local function saveCallback(success, err)
    if success then
        print("User save successful!")
    else
        print("Save failed. Error:", err)
    end
end

-- Call save with a callback
userInstance:save(nil, saveCallback)

function User:handleRelationships(entityId, relationshipData, callback)
    self:Super('handleRelationships', entityId, relationshipData, callback)
end

-- Transaction example
-- Define the User:saveWithTransaction method
function User:saveWithTransaction(data, callback)
    -- Begin a transaction
    self:beginTransaction(function(success, err)
        if not success then
            -- Handle transaction start failure
            if callback then
                callback(false, "Failed to begin transaction: " .. (err or "Unknown error"))
            end
            return
        end

        -- Perform the save operation
        self:save(data, function(saveSuccess, saveErr)
            if saveSuccess then
                -- Commit the transaction
                self:commitTransaction(function(commitSuccess, commitErr)
                    if callback then
                        callback(commitSuccess, commitErr)
                    end
                end)
            else
                -- Rollback the transaction
                self:rollbackTransaction(function(rollbackSuccess, rollbackErr)
                    if callback then
                        callback(false, "Save failed and rollback: " .. (rollbackErr or "Unknown error"))
                    end
                end)
            end
        end)
    end)
end

local function transactionCallback(success, err)
    if success then
        print("User saved and transaction committed successfully!")
    else
        print("Error:", err)
    end
end

-- Call saveWithTransaction with a callback
userInstance.name = 'Markiplier3'
userInstance:saveWithTransaction(nil, transactionCallback)
-- Simulate an update with a non-existent record
userInstance:saveWithTransaction({ id = 9999, namee = 'ExistingUser' }, transactionCallback)

local myRes = {}

-- Query users with chaining
-- 'SELECT id, name, age FROM users WHERE age = ? 
-- AND (NOT (name = ?) OR name = ?) AND LOWER(name) LIKE LOWER(?) ORDER BY age DESC LIMIT 20 OFFSET 0'

-- 'SELECT id, name, age FROM users WHERE age = ? AND name = ? AND (name = ? OR NOT (name = ?)) AND LOWER(name) LIKE LOWER(?) ORDER BY age DESC LIMIT 20 OFFSET 0'

-- Creating Q instances with specific logical operations
local nameMarkiplier = Q:new("name", "Markiplier")
local nameJohnDoeNot = Q:new("name", "JohnDoe"):NOT()

-- Combining conditions: name should be Markiplier OR NOT JohnDoe
local combinedCondition = nameMarkiplier:OR(nameJohnDoeNot)

User.objects
    :values({'id', 'name', 'age'})
    :filter({ 
        name__icontains = "Markiplier",
        Q:new("age", 59),
        Q:new("name", "Markiplier3"),
        combinedCondition
    })
    :order("age DESC")
    :limit(20)
    :offset(0)
    :get(function(results, err)
        if err then
            print("Error: " .. err)
        else
            for _, result in ipairs(results) do
                print(string.format("%s %s %s", result.id, result.name, result.age))

                userInstance:find(result.id, function(user, err)
                    if err then
                        print("Error:", err)
                    elseif user then
                        print("User found:", user[1].name)
                    else
                        print("User not found.")
                    end
                end)

            end
            myRes = results
        end
    end)

    print(myRes)
