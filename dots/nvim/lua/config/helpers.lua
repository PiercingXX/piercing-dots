---@diagnostic disable: undefined-global
local M = {}

-- Generic protected require helper with optional setup callback.
-- Example: require('config.helpers').try('module', function(m) m.setup({}) end)
function M.try(mod, fn)
  local ok, m = pcall(require, mod)
  if not ok then return nil end
  if fn then
    local ok2, err = pcall(fn, m)
    if not ok2 then
      vim.schedule(function()
        vim.notify('setup failed for ' .. mod .. ': ' .. err, vim.log.levels.WARN)
      end)
    end
  end
  return m
end

return M
