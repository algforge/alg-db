ResultProcessor = {}
ResultProcessor.__index = ResultProcessor

-- Constructor for ResultProcessor
function ResultProcessor:new(return_as_dict, columns)
    local self = setmetatable({}, self)
    self.return_as_dict = return_as_dict
    self.columns = columns or {}  -- Default to empty table if not provided
    return self
end

-- Method to process results based on the type
function ResultProcessor:process(results)
    local processed_results = {}

    for _, row in ipairs(results) do
        local processed_row = {}

        if self.return_as_dict then
            if #self.columns > 0 then
                -- Use only the specified columns
                for _, col in ipairs(self.columns) do
                    processed_row[col] = row[col]
                end
            else
                -- Use all columns if none specified
                for col, val in pairs(row) do
                    processed_row[col] = val
                end
            end
        else
            if #self.columns > 0 then
                -- Use specified columns only
                for _, col in ipairs(self.columns) do
                    table.insert(processed_row, row[col])
                end
            else
                -- Use all columns if none specified
                for _, val in ipairs(row) do
                    table.insert(processed_row, val)
                end
            end
        end

        table.insert(processed_results, processed_row)
    end

    return processed_results
end

return ResultProcessor
