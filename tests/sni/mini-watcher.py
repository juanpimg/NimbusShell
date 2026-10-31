#!/usr/bin/env python3
# mini-watcher (F3-T07-fix): StatusNotifierWatcher mínimo para el test de
# unregister sin kwin/plasmashell. Implementa lo que usa el modelo:
# prop RegisteredStatusNotifierItems, señales ItemRegistered/Unregistered
# y método RegisterStatusNotifierItem(service). Sigue NameOwnerChanged:
# si el dueño del servicio desaparece -> Unregistered (igual que el
# watcher real cuando muere un item).
import sys
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

BUS = "org.kde.StatusNotifierWatcher"
PATH = "/StatusNotifierWatcher"
IFACE = "org.kde.StatusNotifierWatcher"


class Watcher(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, PATH)
        self.bus = bus
        self.items = []  # "servicio/ruta"
        bus.add_signal_receiver(
            self.on_owner_changed,
            signal_name="NameOwnerChanged",
            dbus_interface="org.freedesktop.DBus",
        )

    def on_owner_changed(self, name, old, new):
        if not name or name.startswith(":") is False:
            pass
        gone = [i for i in self.items if i.split("/")[0] == name and not new]
        for i in gone:
            self.items.remove(i)
            self.StatusNotifierItemUnregistered(i)
            print(f"watcher: Unregistered {i}", flush=True)

    @dbus.service.method(IFACE, in_signature="s", out_signature="")
    def RegisterStatusNotifierItem(self, service):
        # Path por defecto del spec: /StatusNotifierItem
        item = service + "/StatusNotifierItem"
        if item not in self.items:
            self.items.append(item)
            self.StatusNotifierItemRegistered(item)
            print(f"watcher: Registered {item}", flush=True)

    @dbus.service.method(
        dbus.PROPERTIES_IFACE, in_signature="ss", out_signature="v"
    )
    def Get(self, iface, prop):
        if prop == "RegisteredStatusNotifierItems":
            return dbus.Array(self.items, signature="s")
        if prop == "ProtocolVersion":
            return 0
        if prop == "IsStatusNotifierHostRegistered":
            return True
        raise dbus.DBusException("unknown property")

    @dbus.service.method(
        dbus.PROPERTIES_IFACE, in_signature="s", out_signature="a{sv}"
    )
    def GetAll(self, iface):
        return {
            "RegisteredStatusNotifierItems": dbus.Array(
                self.items, signature="s"
            ),
            "ProtocolVersion": 0,
            "IsStatusNotifierHostRegistered": True,
        }

    @dbus.service.signal(IFACE, signature="s")
    def StatusNotifierItemRegistered(self, item):
        pass

    @dbus.service.signal(IFACE, signature="s")
    def StatusNotifierItemUnregistered(self, item):
        pass


DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
bus.request_name(BUS, dbus.bus.NAME_FLAG_DO_NOT_QUEUE)
Watcher(bus)
print("watcher: listo DEPLOY_OK", flush=True)
GLib.MainLoop().run()
