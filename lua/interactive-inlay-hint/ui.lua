local api = vim.api
local lsp = vim.lsp
local methods = lsp.protocol.Methods
local lsp_util = lsp.util
local keymap = vim.keymap.set

local M = {}

local auto_focus = true

local state = {
    ---@type integer
    winnr = nil,
    ---@type integer
    bufnr = nil,
    hover = {
        ---@type integer
        winnr = nil,
        ---@type integer
        bufnr = nil,

        categories = {
            ---@type integer
            winnr = nil,
            ---@type integer
            bufnr = nil,
            ---@type "tooltip"|"location"
            tooltip_location = nil,
        },
    },
}

local function close_hover()
    api.nvim_win_close(state.winnr, true)
end

---@param label string|lsp.MarkedString|lsp.MarkedString[]|lsp.MarkupContent
local function handle_float(label)
    local markdown_lines = lsp_util.convert_input_to_markdown_lines(label, {})

    if vim.tbl_isempty(markdown_lines) then
        return
    end

    ---TODO: add config
    ---@type vim.lsp.util.open_floating_preview.Opts
    local win_opt = { max_width = 80, max_height = 30, border = "rounded" }

    local bufnr, winnr = lsp_util.open_floating_preview(
        markdown_lines,
        "markdown",
        vim.tbl_extend("keep", win_opt, {
            focusable = true,
            focus_id = "inaly-hint-label",
            close_events = { "CursorMoved", "CursorMovedI", "BufHidden" },
        })
    )

    api.nvim_create_autocmd("WinEnter", {
        callback = function()
            api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
        end,
        buffer = bufnr,
    })

    if auto_focus then
        api.nvim_set_current_win(winnr)

        api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
    end

    if state.winnr ~= nil then
        return
    end

    state.winnr = winnr
    keymap("n", "q", close_hover, { buffer = bufnr, silent = true })
    keymap("n", "<Esc>", close_hover, { buffer = bufnr, silent = true })

    api.nvim_buf_attach(bufnr, false, {
        on_detach = function()
            state.winnr = nil
        end,
    })

    vim.wo[winnr].signcolumn = "no"
end

---@type lsp.Handler
---@param inlay_hint lsp.InlayHint
local function lsp_handler(_, inlay_hint, ctx)
    local client = lsp.get_clients({
        bufnr = ctx.bufnr,
        client_id = ctx.client_id,
        method = methods.textDocument_inlayHint,
    })[1]

    if not inlay_hint then
        return
    end
    local label = inlay_hint.label
    if type(label) == "string" then
        handle_float(label)
        return
    end

    ---@type lsp.InlayHintLabelPart[]
    local location_parts = vim.tbl_filter(
        ---@param part lsp.InlayHintLabelPart
        function(part)
            return part.location ~= nil
        end,
        label
    )

    local part = location_parts[1]
    if part then
        client:request(methods.textDocument_hover, {
            textDocument = { uri = part.location.uri },
            position = part.location.range.start,
        }, function(_, result, _)
            handle_float(result.contents)
        end)
        return
    end

    ---@type lsp.InlayHintLabelPart[]
    local tooltip_parts = vim.tbl_filter(
        ---@param part_ lsp.InlayHintLabelPart
        function(part_)
            return part_.tooltip ~= nil
        end,
        label
    )
    part = tooltip_parts[1]
    handle_float(part.tooltip)
end

---@param hint vim.lsp.inlay_hint.get.ret
M.req = function(hint)
    local client = lsp.get_clients({
        bufnr = hint.bufnr,
        client_id = hint.client_id,
        method = methods.textDocument_inlayHint,
    })[1]
    client:request(methods.inlayHint_resolve, hint.inlay_hint, lsp_handler, hint.bufnr)
end

return M
