local inlay_hint  = vim.lsp.inlay_hint
local utils = require("interactive-inlay-hint.utils")
local ui = require("interactive-inlay-hint.ui")
local config = require("interactive-inlay-hint.config")

local M = {}

---@param opts inter_inlay_config
M.setup = function(opts)
    config.setup(opts)
end

---@return boolean
M.exists_inlay_hint = function()
    return #inlay_hint.get({ bufnr = 0, range = utils.select_word() }) > 0
end

---Return the inalyhint count
---@return integer
M.interaction_inlay_hint = function()
    local hint_list = inlay_hint.get({ bufnr = 0, range = utils.select_word() })
    ui.float_ui(hint_list)

    return #hint_list
end

return M
