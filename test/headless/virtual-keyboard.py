#!/usr/bin/env python3
"""Holds a Mutter RemoteDesktop session open with a virtual keyboard so the
headless seat gains keyboard capability. Runs until terminated."""
import signal
import gi
gi.require_version('Gio', '2.0')
from gi.repository import Gio, GLib

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
def call(path, iface, method, params=None, reply=None):
    return bus.call_sync('org.gnome.Mutter.RemoteDesktop', path, iface, method, params,
                         reply, Gio.DBusCallFlags.NONE, -1, None)

session_path = call('/org/gnome/Mutter/RemoteDesktop', 'org.gnome.Mutter.RemoteDesktop',
                    'CreateSession', None, GLib.VariantType('(o)')).unpack()[0]
S = 'org.gnome.Mutter.RemoteDesktop.Session'
call(session_path, S, 'Start')
# One key press and release of Shift creates the virtual keyboard device.
call(session_path, S, 'NotifyKeyboardKeysym', GLib.Variant('(ub)', (0xffe1, True)))
call(session_path, S, 'NotifyKeyboardKeysym', GLib.Variant('(ub)', (0xffe1, False)))
print(f'virtual keyboard ready on {session_path}', flush=True)
loop = GLib.MainLoop()
for sig in (signal.SIGTERM, signal.SIGINT):
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, lambda: loop.quit() or True)
loop.run()
