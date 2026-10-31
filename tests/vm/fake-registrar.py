#!/usr/bin/env python3
# fake-registrar.py (harness F3-T06, solo tests nested).
#
# Por qué existe: Qt6 (QDBusMenuBar, dentro de QtGui) solo exporta el
# menubar en com.canonical.dbusmenu (/MenuBar/N) si el nombre bien
# conocido com.canonical.AppMenu.Registrar existe en el bus de sesión.
# En Plasma 6/Wayland el módulo appmenu de kded6 NO reclama ese nombre
# (verificado: loadedModules contiene "appmenu", org.kde.kappmenu sí
# existe, pero com.canonical.AppMenu.Registrar no — ni en host ni en
# nested). Sin registrar, Kate/Dolphin no exportan nada.
# Este fake reclama el nombre e implementa RegisterWindow/
# UnregisterWindow/GetMenuForWindow con log a stdout. Las apps Qt no
# llegan a llamar a RegisterWindow en Wayland (verificado), pero la
# mera presencia del nombre activa la exportación del menú.
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
bus.request_name("com.canonical.AppMenu.Registrar")


class Registrar(dbus.service.Object):
    def __init__(self):
        super().__init__(bus, "/com/canonical/AppMenu/Registrar")

    @dbus.service.method("com.canonical.AppMenu.Registrar",
                         in_signature="uo", out_signature="",
                         sender_keyword="sender")
    def RegisterWindow(self, wid, path, sender=None):
        try:
            pid = str(bus.get_unix_process_id(sender))
        except Exception:
            pid = "?"
        print(f"FAKE-REG RegisterWindow wid={wid} path={path} pid={pid}",
              flush=True)

    @dbus.service.method("com.canonical.AppMenu.Registrar",
                         in_signature="u", out_signature="")
    def UnregisterWindow(self, wid):
        print(f"FAKE-REG UnregisterWindow wid={wid}", flush=True)

    @dbus.service.method("com.canonical.AppMenu.Registrar",
                         in_signature="u", out_signature="(so)")
    def GetMenuForWindow(self, wid):
        print(f"FAKE-REG GetMenuForWindow wid={wid}", flush=True)
        return ("", dbus.ObjectPath("/"))


Registrar()
print("FAKE-REG listo", flush=True)
GLib.MainLoop().run()
