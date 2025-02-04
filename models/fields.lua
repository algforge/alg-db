-- Define the Field base class
Field = {}
Field.__index = Field

function Field:new(type, options)
    local obj = setmetatable({}, self)
    obj.type = type
    obj.options = options or {}
    return obj
end

-- Define specific field types
IntegerField = setmetatable({}, { __index = Field })
function IntegerField:new(options)
    return Field.new(self, "Integer", options)
end

FloatField = setmetatable({}, { __index = Field })
function FloatField:new(options)
    return Field.new(self, "Float", options)
end

CharField = setmetatable({}, { __index = Field })
function CharField:new(options)
    options.max_length = options.max_length or 255
    return Field.new(self, "Char", options)
end

TextField = setmetatable({}, { __index = Field })
function TextField:new(options)
    return Field.new(self, "Text", options)
end

DateField = setmetatable({}, { __index = Field })
function DateField:new(options)
    return Field.new(self, "Date", options)
end

ForeignKeyField = setmetatable({}, { __index = Field })
function ForeignKeyField:new(relatedModel, options)
    local field = Field.new(self, "ForeignKey", options)
    field.relatedModel = relatedModel
    return field
end

ManyToManyField = setmetatable({}, { __index = Field })
function ManyToManyField:new(relatedModel)
    local field = Field.new(self, "ManyToMany")
    field.relatedModel = relatedModel
    return field
end

return {
    Field = Field,
    IntegerField = IntegerField,
    FloatField = FloatField,
    CharField = CharField,
    TextField = TextField,
    DateField = DateField,
    ForeignKeyField = ForeignKeyField,
    ManyToManyField = ManyToManyField
}
