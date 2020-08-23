--based on https://fingercomp.gitbooks.io/oc-cookbook/content/lua/repl.html

print(_VERSION .. " Copyright (C) 1994-2017 Lua.org, PUC-Rio")
print("Enter a statement and hit enter to evaluate it.")
print("Enter :q to exit the interpreter.")

while true do
  local input = terminal.read()
  

  if input == ":q" then
    print("exit from lua repl")
    return
  end
  
  --print("lua>"..input)

  local chunk, reason = load("return " .. input, "=stdin", "t")

  if not chunk then
    chunk, reason = load(input, "=stdin", "t")
  end

  if not chunk then
    log.error("Syntax error: " .. reason .. "\n")
  else
    local result = table.pack(xpcall(chunk, debug.traceback))
    local success = table.remove(result, 1)
    result.n = result.n - 1

    if not success then
      log.error("Runtime error: " .. result[1] .. "\n")
    elseif result.n > 0 then
      print(table.unpack(result, 1, result.n))
    end
  end
end