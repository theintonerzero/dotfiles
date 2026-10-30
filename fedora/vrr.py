"""turns on variable refresh rate for every monitor that offers it, saved the way gnome settings saves it"""

import sys

from gi.repository import Gio, GLib

BUS_NAME = "org.gnome.Mutter.DisplayConfig"
OBJECT_PATH = "/org/gnome/Mutter/DisplayConfig"
STATE_TYPE = "(ua((ssss)a(siiddada{sv})a{sv})a(iiduba(ssss)a{sv})a{sv})"
PERSISTENT = 2


def plan(monitors, logical_monitors):
    """the layout with each monitor's current mode swapped for its variable twin, or None when nothing changes"""
    modes = {spec[0]: mode_list for spec, mode_list, _ in monitors}
    changed = False
    layout = []
    for x, y, scale, transform, primary, specs, _ in logical_monitors:
        chosen = []
        for spec in specs:
            current = next(m for m in modes[spec[0]] if m[6].get("is-current"))
            pick = current
            if current[6].get("refresh-rate-mode") != "variable":
                for mode in modes[spec[0]]:
                    if (
                        mode[1:3] == current[1:3]
                        and abs(mode[3] - current[3]) < 0.01
                        and mode[6].get("refresh-rate-mode") == "variable"
                    ):
                        pick = mode
                        changed = True
                        break
            chosen.append((spec[0], pick[0], {}))
        layout.append((x, y, scale, transform, primary, chosen))
    return layout if changed else None


def main():
    bus = Gio.bus_get_sync(Gio.BusType.SESSION)
    state = bus.call_sync(
        BUS_NAME, OBJECT_PATH, BUS_NAME, "GetCurrentState", None,
        GLib.VariantType(STATE_TYPE), Gio.DBusCallFlags.NONE, -1, None,
    )
    serial, monitors, logical_monitors, properties = state.unpack()
    layout = plan(monitors, logical_monitors)
    if layout is None:
        print("vrr already on")
        return
    extra = {}
    if "layout-mode" in properties:
        extra["layout-mode"] = GLib.Variant("u", properties["layout-mode"])
    bus.call_sync(
        BUS_NAME, OBJECT_PATH, BUS_NAME, "ApplyMonitorsConfig",
        GLib.Variant("(uua(iiduba(ssa{sv}))a{sv})", (serial, PERSISTENT, layout, extra)),
        None, Gio.DBusCallFlags.NONE, -1, None,
    )
    print("turned on variable refresh rate")


if __name__ == "__main__":
    try:
        main()
    except GLib.Error as error:
        sys.exit(f"vrr.py: {error.message}")
