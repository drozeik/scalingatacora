-- The guide writes display equations as ```math blocks, the form GitHub renders.
-- For the appendix (HTML and PDF), this filter turns them into display math.
function CodeBlock(block)
  if block.classes[1] == "math" then
    return pandoc.Para({ pandoc.Math("DisplayMath", block.text) })
  end
end
