// tst_clock.cpp — Tests unitarios para ClockBackend (F10-T01).
// Prueba cálculo de zonas horarias, adición, persistencia y eliminación de alarmas.
#include <QtTest>
#include <QStandardPaths>
#include <QTemporaryDir>
#include "../clockbackend.h"

class TstClock : public QObject {
    Q_OBJECT
private Q_SLOTS:
    void initTestCase()
    {
        qputenv("NIMBUS_CLOCK_SIM", "1");
    }

    void timeInZones()
    {
        ClockBackend b;
        // Zonas horarias requeridas en Tahoe: Madrid, London, New York, Tokyo
        const QString tMadrid = b.timeInZone(QStringLiteral("Europe/Madrid"), QStringLiteral("HH:mm"));
        QVERIFY(!tMadrid.isEmpty() && tMadrid != QStringLiteral("—"));

        const QString tLondon = b.timeInZone(QStringLiteral("Europe/London"), QStringLiteral("HH:mm"));
        QVERIFY(!tLondon.isEmpty() && tLondon != QStringLiteral("—"));

        const QString tNY = b.timeInZone(QStringLiteral("America/New_York"), QStringLiteral("HH:mm"));
        QVERIFY(!tNY.isEmpty() && tNY != QStringLiteral("—"));

        const QString tTokyo = b.timeInZone(QStringLiteral("Asia/Tokyo"), QStringLiteral("HH:mm"));
        QVERIFY(!tTokyo.isEmpty() && tTokyo != QStringLiteral("—"));

        // Zona inválida retorna guion
        const QString tInvalid = b.timeInZone(QStringLiteral("Invalid/Zone"), QStringLiteral("HH:mm"));
        QCOMPARE(tInvalid, QStringLiteral("—"));
    }

    void isDayCalculation()
    {
        ClockBackend b;
        // Debe responder booleanos válidos sin crasheo
        b.isDayInZone(QStringLiteral("Europe/Madrid"));
        b.isDayInZone(QStringLiteral("Asia/Tokyo"));
        QVERIFY(b.isDayInZone(QStringLiteral("Invalid/Zone"))); // fallback true
    }

    void alarmsLifecycle()
    {
        QTemporaryDir tmpHome;
        QVERIFY(tmpHome.isValid());
        qputenv("HOME", tmpHome.path().toLocal8Bit());
        qputenv("XDG_CONFIG_HOME", (tmpHome.path() + "/.config").toLocal8Bit());

        ClockBackend b;
        QCOMPARE(b.alarms().size(), 0);

        // Validación de límites de hora
        QVERIFY(b.addAlarm(-1, 0, QStringLiteral("Bad")).isEmpty());
        QVERIFY(b.addAlarm(25, 0, QStringLiteral("Bad")).isEmpty());
        QVERIFY(b.addAlarm(8, 60, QStringLiteral("Bad")).isEmpty());

        // Adición correcta
        const QString id1 = b.addAlarm(7, 30, QStringLiteral("Despertador"));
        QVERIFY(!id1.isEmpty());
        QCOMPARE(b.alarms().size(), 1);

        const QString id2 = b.addAlarm(14, 0, QStringLiteral("Reunión"));
        QVERIFY(!id2.isEmpty());
        QCOMPARE(b.alarms().size(), 2);

        // Modificar estado on/off
        b.setAlarmOn(id1, false);
        for (const QVariant &v : b.alarms()) {
            const QVariantMap a = v.toMap();
            if (a.value(QStringLiteral("id")).toString() == id1) {
                QCOMPARE(a.value(QStringLiteral("on")).toBool(), false);
            }
        }

        // Persistencia: nueva instancia lee del ini
        ClockBackend b2;
        QCOMPARE(b2.alarms().size(), 2);

        // Eliminación
        b.removeAlarm(id1);
        QCOMPARE(b.alarms().size(), 1);

        b.removeAlarm(id2);
        QCOMPARE(b.alarms().size(), 0);
    }
};

QTEST_MAIN(TstClock)
#include "tst_clock.moc"
