local M = {}

if vim.fn.has("macunix") ~= 1 then
  return M
end

local english_input_source = "com.apple.keylayout.ABC"
local preferred_macism = "/opt/homebrew/bin/macism"

local function resolve_macism()
  if vim.fn.executable(preferred_macism) == 1 then
    return preferred_macism
  end

  if vim.fn.executable("macism") == 1 then
    return "macism"
  end
end

local macism = resolve_macism()

if not macism then
  return M
end

local saved_input_source = english_input_source

local function last_nonempty_line(output)
  local last_line

  for line in tostring(output or ""):gmatch("[^\r\n]+") do
    if line ~= "" then
      last_line = line
    end
  end

  return last_line
end

local function run_macism(args)
  local command = { macism }

  for _, arg in ipairs(args or {}) do
    table.insert(command, arg)
  end

  if vim.system then
    local result = vim.system(command, { text = true }):wait(1000)

    if not result or result.code ~= 0 then
      return nil
    end

    return vim.trim(result.stdout or "")
  end

  local shell_command = vim.fn.shellescape(macism)

  for _, arg in ipairs(args or {}) do
    shell_command = shell_command .. " " .. vim.fn.shellescape(arg)
  end

  return vim.trim(vim.fn.system(shell_command .. " 2>/dev/null"))
end

local function current_input_source()
  return last_nonempty_line(run_macism())
end

local function set_input_source(input_source)
  if not input_source or input_source == "" then
    return
  end

  run_macism({ input_source })
end

local function is_normal_mode(mode)
  return type(mode) == "string" and mode:sub(1, 1) == "n"
end

local function set_english_if_normal()
  if is_normal_mode(vim.api.nvim_get_mode().mode) then
    set_input_source(english_input_source)
  end
end

function M.set_english()
  set_input_source(english_input_source)
end

function M.save_current()
  local input_source = current_input_source()

  if input_source and input_source ~= "" then
    saved_input_source = input_source
  end
end

function M.restore_saved()
  if saved_input_source ~= english_input_source then
    set_input_source(saved_input_source)
  end
end

local group = vim.api.nvim_create_augroup("ForceEnglishImeOnNormalMode", { clear = true })

vim.api.nvim_create_autocmd("InsertLeave", {
  group = group,
  callback = function()
    M.save_current()
    M.set_english()
  end,
})

vim.api.nvim_create_autocmd("InsertEnter", {
  group = group,
  callback = function()
    M.restore_saved()
  end,
})

vim.api.nvim_create_autocmd("CmdlineLeave", {
  group = group,
  callback = function()
    M.set_english()
  end,
})

vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, {
  group = group,
  callback = set_english_if_normal,
})

vim.api.nvim_create_autocmd("ModeChanged", {
  group = group,
  callback = function()
    local new_mode = vim.v.event and vim.v.event.new_mode or ""

    if not is_normal_mode(new_mode) then
      return
    end

    vim.defer_fn(set_english_if_normal, 10)
  end,
})

return M
