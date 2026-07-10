#!/usr/bin/env python3
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import json
import sys

class NotificationDaemon(dbus.service.Object):
    def __init__(self):
        try:
            bus_name = dbus.service.BusName('org.freedesktop.Notifications', bus=dbus.SessionBus(), do_not_queue=True)
        except dbus.exceptions.NameExistsException:
            print("ERROR: DBus name org.freedesktop.Notifications already exists! Please kill existing notification daemons.", file=sys.stderr)
            sys.exit(1)
        super().__init__(bus_name, '/org/freedesktop/Notifications')
        self.next_id = 1

    @dbus.service.method('org.freedesktop.Notifications', in_signature='susssasa{sv}i', out_signature='u')
    def Notify(self, app_name, replaces_id, app_icon, summary, body, actions, hints, expire_timeout):
        if replaces_id > 0:
            nid = replaces_id
        else:
            nid = self.next_id
            self.next_id += 1
            
        py_summary = str(summary)
        py_body = str(body)
        py_app_name = str(app_name)
        
        msg = {
            "type": "notify",
            "id": nid,
            "app_name": py_app_name,
            "summary": py_summary,
            "body": py_body,
            "expire_timeout": int(expire_timeout)
        }
        print(json.dumps(msg))
        sys.stdout.flush()
        
        return nid

    @dbus.service.method('org.freedesktop.Notifications', in_signature='u', out_signature='')
    def CloseNotification(self, id):
        msg = {
            "type": "close",
            "id": int(id)
        }
        print(json.dumps(msg))
        sys.stdout.flush()
        self.NotificationClosed(id, 2)

    @dbus.service.method('org.freedesktop.Notifications', in_signature='', out_signature='ssss')
    def GetServerInformation(self):
        return ("quickshell-notifications", "Quickshell", "1.0", "1.2")

    @dbus.service.method('org.freedesktop.Notifications', in_signature='', out_signature='as')
    def GetCapabilities(self):
        return dbus.Array(["body", "actions", "persistence"], signature='s')

    @dbus.service.signal('org.freedesktop.Notifications', signature='uu')
    def NotificationClosed(self, id, reason):
        pass

    @dbus.service.signal('org.freedesktop.Notifications', signature='us')
    def ActionInvoked(self, id, action_key):
        pass

if __name__ == '__main__':
    try:
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        daemon = NotificationDaemon()
        loop = GLib.MainLoop()
        loop.run()
    except Exception as e:
        with open("/tmp/notification_daemon_crash.log", "w") as f:
            f.write(str(e))
