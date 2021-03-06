---
-- @author wesen
-- @copyright 2019 wesen <wesen-ac@web.de>
-- @release 0.1
-- @license MIT
--

local ObjectUtils = require("LuaORM/Util/ObjectUtils")
local TableColumn = require("LuaORM/Table/TableColumn")
local Type = require("LuaORM/Util/Type/Type")
local API = LuaORM_API

---
-- Provides methods to configure a equation.
--
-- @type Equation
--
local Equation = {}


---
-- Static list of available operators to chain other equations
--
-- @tfield int[] chainOperators
--
Equation.chainOperators = {
  AND = 1,
  OR = 2
}

---
-- The chain operator id that will be used to chain this Equation to the next Equation (if there is any)
--
-- @tfield int chainOperatorToNextEquation
--
Equation.chainOperatorToNextEquation = Equation.chainOperators.AND

---
-- The equation settings
-- Using a settings table to avoid duplicate table indexes (e.g. "column" attribute and method)
--
-- @tfield mixed[] settings
--
Equation.settings = {

  ---
  -- Indicates whether the whole Equation will be negated (with a leading NOT)
  --
  -- @tfield bool NOT
  --
  NOT = false,

  ---
  -- The target that will be compared to a value (text, number, etc.)
  --
  -- @tfield TableColumn|SelectRule target
  --
  target = nil,


  -- Equation Type A: The column is compared to a value

  ---
  -- The operator that will be used to compare the column and the value
  -- This can be either "<", "<=", "=", ">" or ">="
  --
  -- @tfield string operator
  --
  operator = nil,

  ---
  -- The value to compare the column to
  --
  -- @tfield mixed value
  --
  value = nil,


  -- Equation Type B: The column is compared to a pattern

  ---
  -- The pattern for the LIKE comparison
  --
  -- @tfield string isLikePattern
  --
  isLikePattern = nil,


  -- Equation Type C: The column is compared to a list of values

  ---
  -- The list of values of which one has to equal the column value
  --
  -- @tfield mixed[] inValueList
  --
  isInValueList = nil,


  -- Equation Type D: The column is compared to the "value not set" string

  ---
  -- If true this Equation will check whether the column value is not set
  --
  -- @tfield bool isNotSet
  --
  isNotSet = nil
}


-- Metamethods

---
-- Equation constructor.
-- This is the __call metamethod.
--
-- @tparam Condition _parentCondition The parent condition
--
-- @treturn Equation The Equation instance
--
function Equation:__construct(_parentCondition)

  local instance = setmetatable({}, {__index = Equation})

  instance.parentCondition = _parentCondition
  instance.settings = ObjectUtils.clone(Equation.settings)

  return instance

end


-- Getters and Setters

---
-- Returns the id of the Equation's chain operator to the next Equation.
--
-- @treturn int The id of the Equation's chain operator to the next Equation
--
function Equation:getChainOperatorToNextEquation()
  return self.chainOperatorToNextEquation
end

---
-- Returns the Equation's settings.
--
-- @treturn mixed[] The Equation's settings
--
function Equation:getSettings()
  return self.settings
end


-- API

---
-- Negates this Equation.
-- "not" is a reserved keyword, therefore the method name is "NOT" in uppercase as a workaround.
--
function Equation:NOT()
  self.settings.NOT = true
end

---
-- Sets the Equation's column.
--
-- @tparam string _columnName The name of the column
--
function Equation:column(_columnName)
  self:changeTarget(Type.toString(_columnName))
end


---
-- Configures a "less than x" Equation.
--
-- @tparam number _maximumValue The maximum value
--
function Equation:isLessThan(_maximumValue)
  self.settings.operator = "<"
  self:changeValue(_maximumValue)
end

---
-- Configures a "less than or equal x" Equation.
--
-- @tparam number _maximumValue The maximum value
--
function Equation:isLessThanOrEqual(_maximumValue)
  self.settings.operator = "<="
  self:changeValue(_maximumValue)
end

---
-- Configures a "greater than x" Equation.
--
-- @tparam number _minimumValue The minimum value
--
function Equation:isGreaterThan(_minimumValue)
  self.settings.operator = ">"
  self:changeValue(_minimumValue)
end

---
-- Configures a "greater than or equal x" Equation.
--
-- @tparam number _minimumValue The minimum value
--
function Equation:isGreaterThanOrEqual(_minimumValue)
  self.settings.operator = ">="
  self:changeValue(_minimumValue)
end

---
-- Configures a "equal x" Equation.
--
-- @tparam mixed _value The value
--
function Equation:equals(_value)

  if (_value == nil) then
    self:isNotSet()
  elseif (Type.isTable(_value)) then
    self:isInValueList(_value)
  else
    self.settings.operator = "="
    self:changeValue(_value)
  end

end

---
-- Configures a "equal target" Equation.
--
-- @tparam string _targetName The target name
--
function Equation:equalsColumn(_targetName)

  local parentClause = self.parentCondition:getParentClause()
  local target = parentClause:getParentQuery():getTargetByName(Type.toString(_targetName))

  if (target == nil) then
    API.ORM:getLogger():error("Error in \"equalsColumn\": Target '" .. Type.toString(_targetName) .. "' does not exist")
  else

    if (ObjectUtils.isInstanceOf(target, TableColumn)) then

      local databaseLanguage = API.ORM:getDatabaseConnection():getDatabaseLanguage()

      self.settings.operator = "="
      self.settings.value = databaseLanguage:getTargetIdentifier(target)

    else
      API.ORM:getLogger():error("Error in \"equalsColumn\": Target must be a TableColumn")
    end

  end

end


---
-- Compares the target to a pattern.
--
-- @tparam string _pattern The pattern
--
function Equation:isLike(_pattern)

  if (Type.isString(_pattern)) then

    if (self.settings.target:hasTextDataType()) then
      local databaseLanguage = API.ORM:getDatabaseConnection():getDatabaseLanguage()
      self.settings.isLikePattern = databaseLanguage:escapeLiteral(_pattern)
    else
      API.ORM:getLogger():error("Error in \"isLike\": Target has no text data type")
    end

  else
    API.ORM:getLogger():error("Error in \"isLike\": Pattern is not a string")
  end

end

---
-- Makes the Equation check that the column value equals one element of a specified list of values.
--
-- @tparam mixed[] _valueList The list of values
--
function Equation:isInList(_valueList)
  self:changeValueList(_valueList)
end


---
-- Makes the Equation check whether the column is not set.
--
function Equation:isNotSet()
  self.settings.isNotSet = true
end

---
-- Finishes this Equation with the and operator and adds a new equation to the parent condition.
-- "and" is a reserved keyword, therefore the method name is "AND" in uppercase as a workaround.
--
function Equation:AND()
  self.chainOperatorToNextEquation = self.chainOperators.AND
  self.parentCondition:addNewEquation()
end

---
-- Finishes this Equation with the or operator and adds a new equation to the parent condition.
-- "or" is a reserved keyword, therefore the method name is "OR" in uppercase as a workaround.
--
function Equation:OR()
  self.chainOperatorToNextEquation = self.chainOperators.OR
  self.parentCondition:addNewEquation()
end


-- Public Methods

---
-- Returns whether this Equation is empty.
-- This is done by checking whether the settings match the default settings.
--
-- @treturn bool True if the equation is empty, false otherwise
--
function Equation:isEmpty()

  for settingName, value in pairs(self.settings) do
    if (value ~= Equation.settings[settingName]) then
      return false
    end
  end

  return true

end

---
-- Returns whether this Equation is valid.
--
-- @treturn bool True if this Equation is valid, false otherwise
--
function Equation:isValid()

  -- Check if the comparison column is set
  if (self.settings.target == nil) then
    return false
  end

  if (self.settings.operator ~= nil) then
    return self:validateComparison()
  else
    return (self.settings.isLikePattern ~= nil or self.settings.isInValueList ~= nil or self.settings.isNotSet ~= nil)
  end

end


-- Private Methods

---
-- Changes the target of this Equation.
--
-- @tparam string _targetName The name of a column or the select alias of a SelectRule
--
function Equation:changeTarget(_targetName)

  local parentQuery = self.parentCondition:getParentClause():getParentQuery()
  local target = parentQuery:getTargetByName(_targetName)
  if (target == nil) then
    API.ORM:getLogger():warn("Can not set Equation's target column: Unknown column '" .. _targetName .. "'")
  else
    self.settings.target = target
  end

end

---
-- Changes the value of this Equation.
--
-- @tparam mixed _value The value
--
function Equation:changeValue(_value)

  if (self.settings.target == nil) then
    API.ORM:getLogger():warn("Cannot change Equations value to '" .. Type.toString(_value) .. "': Compare column was not defined")
  else

    if (self.settings.target:validateValue(_value)) then
      self.settings.value = self.settings.target:getValueQueryString(_value)
    else
      API.ORM:getLogger():warn("Cannot change Equations value to '" .. Type.toString(_value) .. "': Value does not match the columns field type (Column: '" .. self.settings.target:getSelectAlias() .. "')")
    end

  end

end

---
-- Changes the value list for the "in value list" Equation's.
--
-- @tparam mixed[] _valueList The value list
--
function Equation:changeValueList(_valueList)

  if (self.settings.target == nil) then
    API.ORM:getLogger():warn("Cannot change Equations value list to '" .. Type.toString(_valueList) .. "': Target column is not set")
  else

    local valueList = {}
    for _, value in ipairs(_valueList) do

      if (self.settings.target:validateValue(value)) then
        table.insert(valueList, self.settings.target:getValueQueryString(value))
      else
        API.ORM:getLogger():warn("Cannot add value '" .. Type.toString(value) .. "' to Equations value list: Value does not match the columns field type")
      end
    end

    self.settings.isInValueList = valueList

  end

end

---
-- Validates the comparison settings for this Equation.
--
-- @treturn bool True if the comparison settings for this Equation are valid, false otherwise
--
function Equation:validateComparison()

  if (self.settings.operator == "=") then
    return true
  else
    return self.settings.target:hasNumberDataType()
  end

end


-- When Equation() is called, call the __construct() method
setmetatable(Equation, {__call = Equation.__construct})


return Equation
