local lsp_util = vim.lsp.util
local vfn = vim.fn
local log = vim.lsp.log
local api = vim.api
local keymap = vim.keymap.set
local utils = require("interactive-inlay-hint.utils")
local config = require("interactive-inlay-hint.config")

local hover_state = {
    ---@type integer
    winnr = nil,
    ---@type integer
    bufnr = nil,
}

function hover_state:close_hover()
    if self.winnr ~= nil then
        api.nvim_win_close(self.winnr, true)
        self.winnr = nil
        self.bufnr = nil
    end
end

local M = { hover_state = hover_state }

---@type lsp.Handler
M.goto_definition = function(_, result, ctx)
    if result == nil or vim.tbl_isempty(result) then
        local _ = log.info() and log.info(ctx.method, "No location found")
        return nil
    end

    if vim.islist(result) then
        lsp_util.show_document(result[1], "utf-8", { focus = true })

        if #result > 1 then
            vfn.setqflist(lsp_util.locations_to_items(result))
        end
    else
        lsp_util.show_document(result, "utf-8", { focus = true })
    end
end

---@param super_win integer
M.hover = function(result, super_win)
    if result.contents == nil then
        return
    end
    local markdown_lines = lsp_util.convert_input_to_markdown_lines(result.contents, {})
    hover_state.bufnr = api.nvim_create_buf(false, true)

    local width = utils.max_width(markdown_lines)
    local height = #markdown_lines

    ---@type vim.api.keyset.win_config
    local win_opts = vim.tbl_extend("keep", config.values.win_opts, {
        win = super_win,
        -- width = utils.max_width(markdown_lines),
        -- height = #markdown_lines,
        border = "rounded",
        relative = "win",
        row = 1,
        col = -1,
        title = "tooltip",
        title_pos = "center",
    })
    utils.min_width_height(win_opts, width, height)

    hover_state.winnr = api.nvim_open_win(hover_state.bufnr, false, win_opts)

    api.nvim_buf_set_lines(hover_state.bufnr, 0, #markdown_lines, false, markdown_lines)

    utils.set_win_buf_opt(hover_state.winnr, hover_state.bufnr)

    local function quit_win()
        hover_state:close_hover()
        api.nvim_set_current_win(super_win)
    end

    keymap("n", "q", quit_win, { buffer = hover_state.bufnr, silent = true })
    keymap("n", "<Esc>", quit_win, { buffer = hover_state.bufnr, silent = true })
end

return M
