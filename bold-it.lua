local highlight_author_filter = {
  Para = function(el)
    for k = 1, #el.content-2 do
      if el.content[k].t == "Str" and el.content[k].text == "Flournoy"
      and el.content[k+1].t == "Space"
      and el.content[k+2].t == "Str" then
          local text = el.content[k+2].text
          if text:find("^J%.") or text:find("^J%. C%.") then
              local full_name = "Flournoy " .. text
              el.content[k] = pandoc.Strong { pandoc.Str(full_name) }
              table.remove(el.content, k+2)
              table.remove(el.content, k+1)
          end
      end
    end
    return el
  end
}

function Div (div)
  if div.identifier:find("^ref-") then
    return pandoc.walk_block(div, highlight_author_filter)
  end
  return nil
end