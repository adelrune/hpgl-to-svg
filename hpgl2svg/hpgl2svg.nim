import std/sequtils
import std/random
import strutils
import std/strformat
import os

{.experimental: "codeReordering".}

randomize()

type
  PenState = enum
    up, down

type
  Color = array[3, int]

type
  Coordinate = array[2, int]

type
  Plotter = object
    pen_coord: array[2,int]
    # first pen is black, others are random for now
    pen_colors: array[8, Color]
    current_pen: int
    p1: Coordinate
    p2: Coordinate
    hard_clip: array[2,Coordinate]
    pen_state: PenState
    canvas: string
    abs_plot: bool

proc make_plotter(): Plotter =
  var colors: array[8, Color]
  colors[0] = [0,0,0]
  for i in 1..7:
    colors[i] = [rand(255),rand(255),rand(255)]
  var max_x = 16640
  var max_y = 10365
  Plotter(
    pen_coord: [0, 0],
    pen_colors: colors,
    current_pen: 0,
    p1: [0, 0],
    p2: [max_x, max_y],
    hard_clip: [[0, 0], [max_x, max_y]],
    pen_state: PenState.up,
    canvas: "",
    abs_plot: true
  )

var pen_plotter = make_plotter()

proc add_line_to_canvas(new_coord: array[2,int]): void =
  # need to invert y values because svg's y starts from the top and hpgl from the bottom
  let x1 = pen_plotter.pen_coord[0]
  let y1 = pen_plotter.hard_clip[1][1] - pen_plotter.pen_coord[1]
  let x2 = new_coord[0]
  let y2 = pen_plotter.hard_clip[1][1] - new_coord[1]
  let rgb = pen_plotter.pen_colors[pen_plotter.current_pen]
  pen_plotter.canvas.add(
    fmt("""<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="rgb({rgb[0]}, {rgb[1]}, {rgb[2]})" />""")
  )

proc move(coords: seq[int]): void =
# moves the pen, adds line to the svg if the pen is down"""
  if coords.len < 2:
    return
  var new_coord = [coords[0], coords[1]]
  if not pen_plotter.abs_plot:
    # if we are in relative plot mode, converts the arguments to relative
    new_coord[0] += pen_plotter.pen_coord[0]
    new_coord[1] += pen_plotter.pen_coord[1]

  if pen_plotter.pen_state == Penstate.down:
    add_line_to_canvas(new_coord)
  pen_plotter.pen_coord = new_coord
  move(coords[2..^1])

proc hpgl_df(): void =
  # hpgl_sc()
  # hpgl_si()
  # hpgl_sl()
  # hpgl_sm()
  # hpgl_ss()
  discard


proc hpgl_sp(num:int): void =
  #SP : switch pen, changes pen color
  # need to implement no pen
  let last_state = pen_plotter.pen_state
  hpgl_pu()
  pen_plotter.current_pen = num - 1

  if last_state == PenState.down:
    hpgl_pd()

proc hpgl_in(): void =
  #IN : initialize: resets pen position, scaling and user defined scaling points.
  hpgl_df()
  hpgl_pu()
  hpgl_pa(@[0, 0])
  pen_plotter.p1 = pen_plotter.hard_clip[0]
  pen_plotter.p2 = pen_plotter.hard_clip[1]

proc hpgl_pu(coords: seq[int]): void =
  # PU: pen up. can move the pen
  pen_plotter.pen_state = PenState.up
  move(coords)

proc hpgl_pu(): void =
  # PU: pen up. can move the pen
  pen_plotter.pen_state = PenState.up


proc hpgl_pd(coords: seq[int]): void =
  # PD: pen down, can move the pen too
  pen_plotter.pen_state = PenState.down
  move(coords)

proc hpgl_pd(): void =
  # PD: pen down, can move the pen too
  pen_plotter.pen_state = PenState.down

proc hpgl_pa(coords: seq[int]): void =
  # PA : plot absolute, changes the plotting mode to absolute, can move the pen too
  pen_plotter.abs_plot = true
  move(coords)

proc hpgl_pr(coords: seq[int]): void =
  # PR : plot relative, changes the plotting mode to relative, can move the pen.
  pen_plotter.abs_plot = false
  move(coords)

proc parse_file(fname: string): void =
   var hpgl_instructions = readFile(fname).replace("\n","").replace(" ","").split(";")
   for instruction in hpgl_instructions:
     execute_line(instruction)

proc execute_line(instruction: string): void =
  if instruction.len < 2:
    return
  var instruction_name = instruction[0..1]
  var params = map(filter(instruction[2..^1].split(","), proc (x:string): bool = x.len>0), proc (x:string): int = parseInt(x))

  case instruction_name:
    of "IN":
      hpgl_in()
    of "SP":
      hpgl_sp(params[0])
    of "DF":
      hpgl_df()
    of "PU":
      hpgl_pu(params)
    of "PD":
      hpgl_pd(params)
    of "PA":
      hpgl_pa(params)
    of "PR":
      hpgl_pr(params)

parse_file(paramStr(1))

writeFile(paramStr(2), """<?xml version="1.0" encoding="utf-8" ?>
<svg baseProfile="tiny" height="100%" version="1.2" width="100%" xmlns="http://www.w3.org/2000/svg" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:xlink="http://www.w3.org/1999/xlink"><defs/>"""&pen_plotter.canvas&"</svg>")
