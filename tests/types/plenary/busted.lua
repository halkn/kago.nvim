---@meta

---@param name string
---@param body fun()
function describe(name, body) end

---@param name string
---@param body fun()
function it(name, body) end

---@param body fun()
function before_each(body) end

---@param body fun()
function after_each(body) end

local M = {}

---@param file string
function M.run(file) end

return M
