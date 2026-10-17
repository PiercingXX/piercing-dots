-- Lualine theme for colors/aura.lua (picked up automatically by theme = 'auto')
local c = {
  bg = "#110f18",
  bg_alt = "#29263c",
  fg = "#edecee",
  gray = "#6d6d6d",
  purple = "#a277ff",
  green = "#61ffca",
  orange = "#ffca85",
  pink = "#f694ff",
  blue = "#82e2ff",
  red = "#ff6767",
}

local function mode(color)
  return {
    a = { fg = c.bg, bg = color, gui = "bold" },
    b = { fg = color, bg = c.bg_alt },
    c = { fg = c.fg, bg = c.bg },
  }
end

return {
  normal = mode(c.purple),
  insert = mode(c.green),
  visual = mode(c.pink),
  replace = mode(c.red),
  command = mode(c.orange),
  terminal = mode(c.blue),
  inactive = {
    a = { fg = c.gray, bg = c.bg },
    b = { fg = c.gray, bg = c.bg },
    c = { fg = c.gray, bg = c.bg },
  },
}
