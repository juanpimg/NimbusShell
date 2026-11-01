// clockbackend.h — F10-T01. Alarmas persistentes + hora por zona.
// Persistencia: ~/.config/nimbus-clock.ini (QSettings IniFormat, grupo
// "alarms": "HH:MM|etiqueta|on" por clave id). Sin sonido propietario:
// al sonar solo se emite la señal ringing (el QML muestra aviso).
#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QDateTime>
#include <QTimeZone>

class ClockBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList alarms READ alarms NOTIFY alarmsChanged)
    Q_PROPERTY(bool simMode READ simMode CONSTANT)
public:
    explicit ClockBackend(QObject *parent = nullptr);
    QVariantList alarms() const { return m_alarms; }
    bool simMode() const { return m_sim; }
    Q_INVOKABLE QString timeInZone(const QString &tzId, const QString &fmt);
    Q_INVOKABLE bool isDayInZone(const QString &tzId);
    Q_INVOKABLE QString addAlarm(int hour, int minute, const QString &label);
    Q_INVOKABLE void removeAlarm(const QString &id);
    Q_INVOKABLE void setAlarmOn(const QString &id, bool on);
    Q_INVOKABLE QString nowText() const;
Q_SIGNALS:
    void alarmsChanged();
    void ringing(const QString &label);
private:
    void load();
    void save();
    QVariantList m_alarms; // {id,h,m,label,on}
    bool m_sim = false;
};
