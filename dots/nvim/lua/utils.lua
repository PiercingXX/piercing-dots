local M = {}

function M.expand_path(path)
  if path:sub(1, 1) == "~" then
    return (os.getenv("HOME") or "") .. path:sub(2)
  end
  return path
end

-- center_in unused; removed to keep module lean

return M