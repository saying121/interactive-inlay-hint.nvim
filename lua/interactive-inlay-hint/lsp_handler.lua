local lsp = vim.lsp
local lsp_util = lsp.util
local methods = lsp.protocol.Methods
local vfn = vim.fn
local log = lsp.log
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
        pcall(api.nvim_win_close, self.winnr, true)
        self.winnr = nil
        self.bufnr = nil
    end
end

local M = { hover_state = hover_state }

---@type lsp.Handler
M.lsp_location = function(_, result, ctx)
    local encoding = "utf-8"
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if client then
        encoding = client.offset_encoding
    end
    if result == nil or vim.tbl_isempty(result) then
        local _ = log.info() and log.info(ctx.method, "No location found")
        return nil
    end

    if vim.islist(result) then
        lsp_util.show_document(result[1], encoding, { focus = true })

        if #result > 1 then
            vfn.setqflist({}, " ", {
                title = "LSP locations",
                items = lsp_util.locations_to_items(result, encoding),
            })
            api.nvim_command("copen")
            api.nvim_command("wincmd p")
        end
    else
        lsp_util.show_document(result, encoding, { focus = true })
    end
end

---@param super_win integer
M.hover = function(result, super_win, col)
    if not (result ~= nil and result.contents ~= nil) then
        return
    end
    local markdown_lines = lsp_util.convert_input_to_markdown_lines(result.contents, {})
    hover_state.bufnr = api.nvim_create_buf(false, true)

    local width = utils.max_width(markdown_lines)
    local height = #markdown_lines

    ---@diagnostic disable-next-line: undefined-field
    local leftcol = vim.fn.getwininfo(super_win)[1].leftcol

    ---@type vim.api.keyset.win_config
    local win_opts = vim.tbl_extend("keep", config.values.win_opts, {
        win = super_win,
        border = "rounded",
        relative = "win",
        row = 2,
        col = col - 1 - leftcol,
    })
    utils.min_width_height(win_opts, width, height)
    -- Increase the width, it looks very thin
    win_opts.width = win_opts.width + 5

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

---@type lsp.Handler
---@param inlay_hint lsp.InlayHint
M.text_edits_handler = function(_, inlay_hint, ctx)
    local _ = lsp.get_clients({
        bufnr = ctx.bufnr,
        client_id = ctx.client_id,
        method = methods.textDocument_inlayHint,
    })[1]
    if not inlay_hint then
        return
    end

    -- if part then
    --     client:request(methods.textDocument_hover, {
    --         textDocument = { uri = part.location.uri },
    --         position = part.location.range.start,
    --     }, function(_, result, _)
    --         handle_float(result.contents)
    --     end)
    --     return
    -- end
end

return M
