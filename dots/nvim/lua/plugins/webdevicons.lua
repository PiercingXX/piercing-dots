-- Deprecated: Lazy.nvim-style plugin spec (nvim-web-devicons)
return {}
return {
	"nvim-tree/nvim-web-devicons",
	config = function()
		require("nvim-web-devicons").setup({})
	end,
	priority = 1000,
}
