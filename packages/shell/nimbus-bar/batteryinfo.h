// batteryinfo.h — batería real para la barra (F3-T05, sin activos Apple).
// Lee /sys/class/power_supply; si no hay batería (VM/Mac mini), present=false
// y la barra oculta el icono. Sondea cada 30 s sin bloquear.
#pragma once

#include <QDir>
#include <QFile>
#include <QObject>
#include <QString>
#include <QTimer>

class BatteryInfo : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool present READ present NOTIFY changed)
    Q_PROPERTY(int charge READ charge NOTIFY changed)
    Q_PROPERTY(bool charging READ charging NOTIFY changed)

public:
    explicit BatteryInfo(QObject *parent = nullptr) : QObject(parent)
    {
        m_timer.setInterval(30000);
        QObject::connect(&m_timer, &QTimer::timeout, this, &BatteryInfo::refresh);
        m_timer.start();
        refresh();
    }

    bool present() const { return m_present; }
    int charge() const { return m_charge; }
    bool charging() const { return m_charging; }

signals:
    void changed();

private:
    void refresh()
    {
        bool present = false;
        int charge = 0;
        bool charging = false;
        const QString base = QStringLiteral("/sys/class/power_supply");
        const QStringList entries = QDir(base).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &entry : entries) {
            QFile type(base + QLatin1Char('/') + entry + QStringLiteral("/type"));
            if (!type.open(QIODevice::ReadOnly))
                continue;
            if (QString::fromLatin1(type.readAll()).trimmed() != QLatin1String("Battery"))
                continue;
            present = true;
            QFile cap(base + QLatin1Char('/') + entry + QStringLiteral("/capacity"));
            if (cap.open(QIODevice::ReadOnly))
                charge = QString::fromLatin1(cap.readAll()).trimmed().toInt();
            QFile status(base + QLatin1Char('/') + entry + QStringLiteral("/status"));
            if (status.open(QIODevice::ReadOnly))
                charging = QString::fromLatin1(status.readAll()).trimmed()
                    == QLatin1String("Charging");
        }
        charge = qBound(0, charge, 100);
        if (present != m_present || charge != m_charge || charging != m_charging) {
            m_present = present;
            m_charge = charge;
            m_charging = charging;
            emit changed();
        }
    }

    QTimer m_timer;
    bool m_present = false;
    int m_charge = 0;
    bool m_charging = false;
};
