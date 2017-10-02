
# Javascript Helpers
# ------------------------------------------------------------------------------

type = (item) ->
  Object::toString.call(item)[8...-1].toLowerCase()

# Vue / Layout
# ------------------------------------------------------------------------------

bus = new Vue()

Vue.component "v-page",
  data: ->
    style:
      width: "100%"
      height: "100vh"
  template: """
    <div :style="style">
      <slot></slot>
    </div>
    """

Vue.component "v-button",
  props: ["name"]
  data: ->
    style:
      display: "inline-block"
      padding: "0.5em"
      pointerEvents: "auto"
      backgroundColor: "rgba(0,0,0,0)"
      cursor: "default"
    highlight: false
    counter: 0

  template: """
    <div 
      :style="style"
      @click="click"
      @mouseenter="highlight = true"
      @mouseleave="highlight = false">
      <i :class="classes"></i>
    </div>
    """
  watch:
    highlight: (status) ->
      this.style.cursor = if status then "pointer" else "default"

  computed:
    classes: -> ["fa", "fa-" + this.name]

  methods:
    click: (event) ->
      this.$emit("v-click", event)

Vue.component "v-svg",
  props: 
    viewBox: 
      type: Array
      default: -> [-8, -4.5, 16, 9] # xmin, ymin, width, height.

  data: ->
    boundingBox: 
      [1, 1, 1, 1] # "external" viewport in px
    style: 
      width: "100%"
      height: "100vh"
      backgroundColor: "white"
    drag:
      active: off
      x: 0
      y: 0
    aim: [0,0]
    overlay:
      style:
        position: "absolute"
        top: "0"
        left: "0"
        width: "100%"
        height: "100%"
        pointerEvents: "none"
    dock:
      style:
        position: "absolute"
        top: "0"
        left: "0"
        width: "100%"
        height: "auto"
        fontSize: "5vmin"
        
  template: """
    <div style="position: relative">
      <svg 
        :viewBox="flippedViewBox" 
        preserveAspectRatio="xMidYMid meet"
        shape-rendering="optimizePrecision"
        :style="style"
        @mousedown="startDrag"
        @mousemove="onDrag"
        @mouseup="stopDrag"
        ref="svg">
          <g transform="scale(1,-1)">
            <slot> 
            </slot>
          </g>
       </svg>
       <div class="overlay" :style="overlay.style">
         <div class="dock" :style="dock.style">
           <v-button name="camera-retro" @v-click="snapshot"></v-button>
         </div>
       </div>
     </div>
     """
  methods:
    onResize: ->
      elt = this.$refs.svg
      bbox = elt.getBoundingClientRect()
      this.boundingBox = [bbox.left, bbox.top, bbox.width, bbox.height]

    convert: (coords, bbox, viewbox) ->
      [X, Y] = coords
      [u, v] = [(X - bbox[0]) / bbox[2], (Y - bbox[1]) / bbox[3]]
      v = 1 - v # flip
      x = viewbox[0] + u * viewbox[2]
      y = viewbox[1] + v * viewbox[3]
      return [x, y]

    startDrag: (e) -> 
      #this.style.cursor = "grabbing"
      this.drag.active = true
      [this.drag.x, this.drag.y] = this.convert([e.pageX, e.pageY], 
                                                this.boundingBox,
                                                this.effectiveViewport)
      bus.$emit("aim", [this.drag.x, this.drag.y])

    onDrag: (e) -> 
      if this.drag.active
        this.startDrag(e)

    stopDrag: -> 
      #this.style.cursor = "grab"
      this.drag.active = false

    snapshot: ->
      console.log "snapshot"
      anchor = document.createElement "a"
      # need to duplicate the SVG and to tweak some shit (e.g. size)
      svg = this.$refs.svg.cloneNode(true) # deep cloning
      svg.setAttribute "width", "1600px"
      svg.setAttribute "height", "900px"
      svg.style.width = undefined
      svg.style.height = undefined
      anchor.setAttribute "href", 
        "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg.outerHTML)
      anchor.setAttribute "download", "figure.svg"

      event = document.createEvent "MouseEvents"
      event.initEvent "click", true, true
      anchor.dispatchEvent event

  computed:
    flippedViewBox: ->
      vb = this.viewBox[...]
      vb[1] = - vb[1] - vb[3]
      return vb.join " "

    effectiveViewport: ->
      # relies on the preserveAspectRatio="xMidYMid meet" policy
      [bbXmin, bbYmin, bbWidth, bbHeight] = this.boundingBox
      [xmin, ymin, width, height] = this.viewBox[...]
      if bbWidth / bbHeight >= width / height
        newWidth = (bbWidth / bbHeight) * height
        xmin = xmin - (newWidth - width) / 2
        width = newWidth 
      else
        newHeight = (bbHeight / bbWidth) * width
        ymin = ymin - (newHeight - height) / 2
        height = newHeight 
      return [xmin, ymin, width, height] 


  mounted: ->
    this.onResize()
    window.addEventListener "resize", this.onResize


      
# SVG Elements 
# ------------------------------------------------------------------------------

Vue.component "wheel",
  props:
    swivelRadius:
      default: 0.5
    wheelOffset:
      default: 2
    wheelWidth: 
      default: 0.5
    wheelRadius:
      default: 1
  data: ->
    x: 0
    y: 0
    gamma: 0
    target:
      x: 0
      y: 0
    animation:
      origin:
        x: 0
        y: 0
        gamma: 0
      id: undefined
      t: 0.0
      T: 3.0
      date: undefined
 
  template: """
    <g>
    <circle r="0.25" :cx="target.x" :cy="target.y" style="fill:red"></circle>
    <g :transform="transform">
      <circle 
        :r="swivelRadius">
      </circle>
      <rect 
        :width="2 * wheelRadius" :height="wheelWidth" 
        :transform="wheelTransform">
      </rect>
    </g>
    </g>
    """
  computed:
    transform: -> """
      translate(#{this.x}, #{this.y}) 
      rotate(#{this.gamma / Math.PI * 180.0} 0 0)
      """
    wheelTransform: ->
      "translate(#{this.wheelOffset - this.wheelRadius}, #{-this.wheelWidth/2})"

  watch:
    target: ->
      if this.animation.id?
        window.cancelAnimationFrame(this.animation.id)
      this.animation.t = 0
      this.animation.date = undefined
      this.animation.origin.x = this.x
      this.animation.origin.y = this.y
      this.animation.origin.gamma = this.gamma
      update = =>
        date = +new Date()
        old = this.animation.date
        if not old?
          old = this.animation.date = date
        dt = (date - old) / 1000
        t = this.animation.t += dt
        this.animation.date = date
        T = this.animation.T
        this.x = (1 - t/T) * this.animation.origin.x + (t/T) * this.target.x
        this.y = (1 - t/T) * this.animation.origin.y + (t/T) * this.target.y
        dx = (dt / T) * (this.target.x - this.animation.origin.x)
        dy = (dt / T) * (this.target.y - this.animation.origin.y)
        this.gamma += (dx * Math.sin(this.gamma) - dy * Math.cos(this.gamma)) \ 
                      / this.wheelOffset 
        if t < this.animation.T
          this.animation.id = window.requestAnimationFrame(update)
        else
          this.animation.t = 0
      this.animation.id = window.requestAnimationFrame(update)

  created: ->
    bus.$on "aim", (xy) =>
      this.target = {x: xy[0], y: xy[1]}

Vue.component "v-demo",
  template: 
    """
    <v-page>
      <v-svg>
        <wheel>
        </wheel>
      </v-svg>
    </v-page>
    """


# Main Component
# ------------------------------------------------------------------------------

main = ->
  new Vue 
    el: "#app"
    template: "<v-demo></v-demo>"

document.addEventListener "DOMContentLoaded", main


