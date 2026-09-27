local config_home = os.getenv("XDG_CONFIG_HOME")
if not config_home or config_home == "" then
  config_home = os.getenv("HOME") .. "/.config"
end
local handle = io.open(config_home .. "/hypr/am01s-output", "r")
local output = handle and handle:read("*l") or nil
if handle then handle:close() end
if output and output ~= "" then
  hl.device({ name = "puya-touch--screen", output = output })
  hl.workspace_rule({ workspace = "11", monitor = output, default = true })
end
