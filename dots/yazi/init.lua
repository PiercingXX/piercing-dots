-- ~/.config/yazi/init.lua
local function safe_setup(name, opts)
	local ok, plugin = pcall(require, name)
	if ok and type(plugin.setup) == "function" then
		plugin:setup(opts or {})
	end
end

safe_setup("relative-motions", { show_numbers = "relative", show_motion = true, enter_mode = "first" })
safe_setup("recycle-bin")
-- require("starship"):setup()
safe_setup("bookmarks", {
	last_directory = { enable = false, persist = false, mode="dir" },
	persist = "all",
	desc_format = "parent",
	file_pick_mode = "hover",
	custom_desc_input = false,
	show_keys = true,
	notify = {
		enable = false,
		timeout = 1,
		message = {
			new = "New bookmark '<key>' -> '<folder>'",
			delete = "Deleted bookmark in '<key>'",
			delete_all = "Deleted all bookmarks",
		},
	},
})

