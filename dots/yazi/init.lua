-- ~/.config/yazi/init.lua
require("relative-motions"):setup({ show_numbers="relative", show_motion = true, enter_mode ="first" })
require("recycle-bin"):setup()
require("starship"):setup()
require("full-border"):setup {
	-- Available values: ui.Border.PLAIN, ui.Border.ROUNDED
	type = ui.Border.ROUNDED,
}
require("bookmarks"):setup({
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

