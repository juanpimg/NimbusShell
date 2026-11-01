// clockbackend.cpp — F10-T01. QDateTime/QTimeZone reales, QSettings ini.
#include "clockbackend.h"
#include <QSettings>
#include <QFile>
#include <QDir>
#include <QRandomGenerator>

ClockBackend::ClockBackend(QObject *parent)
    : QObject(parent)
{
    m_sim = !qEnvironmentVariableIsEmpty("NIMBUS_CLOCK_SIM");
    load();
}

QString ClockBackend::timeInZone(const QString &tzId, const QString &fmt)
{
    QTimeZone tz(tzId.toUtf8());
    if (!tz.isValid())
        return QStringLiteral("—");
    return QDateTime::currentDateTimeUtc().toTimeZone(tz).toString(fmt);
}

bool ClockBackend::isDayInZone(const QString &tzId)
{
    QTimeZone tz(tzId.toUtf8());
    if (!tz.isValid())
        return true;
    const int h = QDateTime::currentDateTimeUtc().toTimeZone(tz).time().hour();
    return h >= 7 && h < 20;
}

QString ClockBackend::nowText() const
{
    return QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss"));
}

QString ClockBackend::addAlarm(int hour, int minute, const QString &label)
{
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59)
        return {};
    const QString id = QString::number(QDateTime::currentMSecsSinceEpoch(), 36)
        + QString::number(QRandomGenerator::global()->bounded(46656), 36);
    QVariantMap a;
    a[QStringLiteral("id")] = id;
    a[QStringLiteral("h")] = hour;
    a[QStringLiteral("m")] = minute;
    a[QStringLiteral("label")] = label.isEmpty() ? QStringLiteral("Alarma") : label;
    a[QStringLiteral("on")] = true;
    m_alarms.append(a);
    save();
    Q_EMIT alarmsChanged();
    return id;
}

void ClockBackend::removeAlarm(const QString &id)
{
    for (int i = 0; i < m_alarms.size(); ++i) {
        if (m_alarms[i].toMap().value(QStringLiteral("id")).toString() == id) {
            m_alarms.removeAt(i);
            save();
            Q_EMIT alarmsChanged();
            return;
        }
    }
}

void ClockBackend::setAlarmOn(const QString &id, bool on)
{
    for (int i = 0; i < m_alarms.size(); ++i) {
        QVariantMap a = m_alarms[i].toMap();
        if (a.value(QStringLiteral("id")).toString() == id) {
            a[QStringLiteral("on")] = on;
            m_alarms[i] = a;
            save();
            Q_EMIT alarmsChanged();
            return;
        }
    }
}

void ClockBackend::load()
{
    QSettings s(QDir::homePath() + QStringLiteral("/.config/nimbus-clock.ini"),
                QSettings::IniFormat);
    const QStringList ids = s.childGroups();
    for (const QString &id : ids) {
        s.beginGroup(id);
        QVariantMap a;
        a[QStringLiteral("id")] = id;
        a[QStringLiteral("h")] = s.value(QStringLiteral("h"), 8).toInt();
        a[QStringLiteral("m")] = s.value(QStringLiteral("m"), 0).toInt();
        a[QStringLiteral("label")] = s.value(QStringLiteral("label"), QStringLiteral("Alarma")).toString();
        a[QStringLiteral("on")] = s.value(QStringLiteral("on"), true).toBool();
        s.endGroup();
        m_alarms.append(a);
    }
}

void ClockBackend::save()
{
    QSettings s(QDir::homePath() + QStringLiteral("/.config/nimbus-clock.ini"),
                QSettings::IniFormat);
    s.clear();
    for (const QVariant &v : m_alarms) {
        const QVariantMap a = v.toMap();
        s.beginGroup(a.value(QStringLiteral("id")).toString());
        s.setValue(QStringLiteral("h"), a.value(QStringLiteral("h")));
        s.setValue(QStringLiteral("m"), a.value(QStringLiteral("m")));
        s.setValue(QStringLiteral("label"), a.value(QStringLiteral("label")));
        s.setValue(QStringLiteral("on"), a.value(QStringLiteral("on")));
        s.endGroup();
    }
    s.sync();
}
