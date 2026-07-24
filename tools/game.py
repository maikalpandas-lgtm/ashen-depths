#!/usr/bin/env python3
"""Talk to the running game over the McpInteractionServer socket (port 9090).

The point of this file is that the agent stops fixing the UI blind. The game
already ships a TCP command server as an autoload; this is the other half — it
grabs a real frame and writes it to shots/auto/, which the agent then reads.

Run the game (any way you like) and leave it open, then:

    python3 tools/game.py shot                 # frame -> shots/auto/<name>.png
    python3 tools/game.py shot --name combat
    python3 tools/game.py key F                # press a key
    python3 tools/game.py click 640 400
    python3 tools/game.py drag 400 660 560 400
    python3 tools/game.py eval 'get_viewport().size'
    python3 tools/game.py raw '{"command":"get_ui_elements"}'

Every command prints the JSON reply (minus the base64 blob), so failures are
visible instead of silent.
"""

import argparse
import base64
import json
import os
import socket
import sys
import time

HOST = "127.0.0.1"
PORT = 9090
SHOT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "shots", "auto")


class Game:
    def __init__(self, timeout=20.0):
        self.sock = socket.create_connection((HOST, PORT), timeout=5.0)
        self.sock.settimeout(timeout)
        self.buf = b""
        self._id = 0

    def send(self, command, **params):
        self._id += 1
        msg = {"command": command, "params": params, "id": self._id}
        self.sock.sendall((json.dumps(msg) + "\n").encode("utf-8"))
        return self._recv_line()

    def send_raw(self, obj):
        self.sock.sendall((json.dumps(obj) + "\n").encode("utf-8"))
        return self._recv_line()

    def _recv_line(self):
        # Screenshots are ~1-3 MB of base64, so this must keep reading.
        while b"\n" not in self.buf:
            chunk = self.sock.recv(1 << 16)
            if not chunk:
                raise RuntimeError("game closed the connection")
            self.buf += chunk
        line, self.buf = self.buf.split(b"\n", 1)
        return json.loads(line.decode("utf-8"))

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


def brief(reply):
    """Reply without the megabyte of image data."""
    return {k: v for k, v in reply.items() if k != "data"}


def cmd_shot(game, args):
    reply = game.send("screenshot")
    if not reply.get("success"):
        print(json.dumps(brief(reply), ensure_ascii=False))
        return 1
    os.makedirs(SHOT_DIR, exist_ok=True)
    name = args.name or time.strftime("%H-%M-%S")
    path = os.path.join(SHOT_DIR, name + ".png")
    with open(path, "wb") as fh:
        fh.write(base64.b64decode(reply["data"]))
    print(json.dumps({"path": path, "width": reply.get("width"),
                      "height": reply.get("height")}, ensure_ascii=False))
    return 0


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("shot", help="save a frame to shots/auto/")
    p.add_argument("--name", help="file name without extension")

    p = sub.add_parser("key", help="press a key, e.g. F, ESCAPE, SPACE")
    p.add_argument("key")

    p = sub.add_parser("click")
    p.add_argument("x", type=float)
    p.add_argument("y", type=float)

    p = sub.add_parser("move")
    p.add_argument("x", type=float)
    p.add_argument("y", type=float)

    p = sub.add_parser("drag")
    p.add_argument("x1", type=float)
    p.add_argument("y1", type=float)
    p.add_argument("x2", type=float)
    p.add_argument("y2", type=float)

    p = sub.add_parser("eval", help="run a GDScript expression in the game")
    p.add_argument("expr")

    p = sub.add_parser("wait")
    p.add_argument("frames", type=int, nargs="?", default=1)

    sub.add_parser("ui", help="dump interactive UI elements")

    p = sub.add_parser("raw", help="send a raw JSON command")
    p.add_argument("json")

    args = ap.parse_args(argv)

    try:
        game = Game()
    except OSError as exc:
        print("Игра не запущена (порт %d закрыт): %s" % (PORT, exc), file=sys.stderr)
        print("Запусти игру и оставь окно открытым.", file=sys.stderr)
        return 2

    try:
        if args.cmd == "shot":
            return cmd_shot(game, args)
        if args.cmd == "key":
            reply = game.send("key_press", key=args.key)
        elif args.cmd == "click":
            reply = game.send("click", x=args.x, y=args.y)
        elif args.cmd == "move":
            reply = game.send("mouse_move", x=args.x, y=args.y)
        elif args.cmd == "drag":
            reply = game.send("mouse_drag", from_x=args.x1, from_y=args.y1,
                              to_x=args.x2, to_y=args.y2)
        elif args.cmd == "eval":
            # The server wraps the text in a function body, so a bare
            # expression has to be turned into a `return`.
            code = args.expr
            if "\n" not in code and not code.lstrip().startswith(("return", "var", "print")):
                code = "return " + code
            reply = game.send("eval", code=code)
        elif args.cmd == "wait":
            reply = game.send("wait", frames=args.frames)
        elif args.cmd == "ui":
            reply = game.send("get_ui_elements")
        else:
            reply = game.send_raw(json.loads(args.json))
        print(json.dumps(brief(reply), ensure_ascii=False, indent=2))
        return 0 if not reply.get("error") else 1
    finally:
        game.close()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
