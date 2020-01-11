import svgwrite
from random import randint
from sys import argv

class Plotter():
    pen_coord = [0,0]
    # first pen is black, others are random for now
    pen_colors = [(0, 0, 0), *[tuple([randint(0, 255) for i in range(3)]) for i in range(7)]]
    current_pen = 0
    # assumes an US A3 format sheet
    hard_clip = ((0,16640), (0,10365))
    P1 = hard_clip[0]
    P2 = hard_clip[1]
    overridden_coordinates = None
    # False is up, True is Down
    pen_state = False
    canvas = None

plotter = Plotter()

def parse_file(inname, outname):
    plotter.canvas = svgwrite.Drawing(outname, profile='tiny')
    instructions = []
    with open(inname) as hpglf:
        instructions = filter(None,hpglf.read().replace("\n", "").replace(" ","").split(";"))
    for instruction in instructions:
        instruction.strip()
        instruction_name = instruction[0:2]
        func_to_call = "hpgl_{}".format(instruction_name.lower())
        instruction_params = instruction[2:].split(",")
        if func_to_call in globals():
            globals()[func_to_call](*instruction_params)
        else:
            print("Unsupported instruction : {}".format(instruction))
    plotter.canvas.save()

def hpgl_in(*args):
    plotter.P1 = plotter.hard_clip[0]
    plotter.P2 = plotter.hard_clip[1]
    overridden_coordinates = None

def hpgl_pa(*args):
    if len(args) < 2:
        return
    new_coord = list(map(lambda x: int(x), args[0:2]))
    if plotter.pen_state:
        plotter.canvas.add(plotter.canvas.line(plotter.pen_coord, new_coord, stroke=svgwrite.rgb(*plotter.pen_colors[plotter.current_pen])))
    plotter.pen_coord = new_coord
    hpgl_pa(*args[2:])

def hpgl_pr(*args):
    if len(args) < 2:
        return
    pa_args = [int(args[i]) + plotter.pen_coord[i] for i in range(2)]
    hpgl_pa(*prargs)
    hpgl_pr(args[2:])

def hpgl_pu(*coords):
    plotter.pen_state = False
    hpgl_pa(*coords)

def hpgl_pd(*coords):
    plotter.pen_state = True
    hpgl_pa(*coords)

def hpgl_sp(num):
    last_state = plotter.pen_state
    hpgl_pu()
    plotter.current_pen = int(num) - 1
    if plotter.pen_state:
        hpgl_pd()

parse_file(argv[1], argv[2])
