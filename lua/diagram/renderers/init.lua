local mermaid = require("diagram/renderers/mermaid")
local plantuml = require("diagram/renderers/plantuml")
local d2 = require("diagram/renderers/d2")
local gnuplot = require("diagram/renderers/gnuplot")

return {
  mermaid = mermaid,
  plantuml = plantuml,
  d2 = d2,
  gnuplot = gnuplot,
}
