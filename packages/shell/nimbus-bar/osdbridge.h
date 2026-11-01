#pragma once
// Puente DBus org.nimbus.OSD (F3-T10): objeto /OSD con show(kind,value).
// Las teclas multimedia y scripts externos llaman:
//   qdbus6 org.nimbus.OSD /OSD org.nimbus.OSD.show volume 0.7
// El adaptador reenvía al slot show del puente; QML lo escucha vía
// Connections (onOsdShow) y abre la burbuja in-situ bajo la barra.
#include <QDBusAbstractAdaptor>
#include <QMetaObject>
#include <QObject>
#include <QString>

class OsdBridge : public QObject {
    Q_OBJECT
public:
    explicit OsdBridge(QObject *parent = nullptr) : QObject(parent) {}
public slots:
    void show(const QString &kind, double value) { emit osdShow(kind, value); }
signals:
    void osdShow(const QString &kind, double value);
};

class OsdAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.nimbus.OSD")
public:
    explicit OsdAdaptor(OsdBridge *bridge) : QDBusAbstractAdaptor(bridge) {}
public slots:
    Q_NOREPLY void show(const QString &kind, double value)
    {
        QMetaObject::invokeMethod(parent(), "show", Q_ARG(QString, kind),
                                  Q_ARG(double, value));
    }
};
