local M = {}
local default = {
    keymaps = {
        goto_def = { "n", "gd" },
        hover = { "n", "K" },
    },
    hover_hi = "LspReferenceText",
    ---@type vim.api.keyset.win_config
    win_opts = {
        width = 80,
        height = 40,
    },
}

M.values = default

M.setup = function(opts)
    M.values = vim.tbl_deep_extend("force", default, opts or {})
end

return M
