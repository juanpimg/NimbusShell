// tst_welcome — progreso/persistencia del wizard F9-T02.
// Usa HOME temporal (el harness lo exporta); QSettings respeta
// XDG_CONFIG_HOME, así nunca toca el HOME real.
#include <QDir>
#include <QFile>
#include <QSettings>
#include <QStandardPaths>
#include <QtTest>

#include "../welcomebackend.h"

class TstWelcome : public QObject {
    Q_OBJECT
private Q_SLOTS:
    void initTestCase()
    {
        qputenv("NIMBUS_WELCOME_SIM", "1");
    }

    void stepBounds()
    {
        WelcomeBackend b;
        b.reset();
        QCOMPARE(b.step(), 0);
        b.setStep(99);
        QCOMPARE(b.step(), 6);
        b.setStep(-3);
        QCOMPARE(b.step(), 0);
        QCOMPARE(b.stepCount(), 7);
        QCOMPARE(b.stepIndexFor(QStringLiteral("appearance")), 4);
        QCOMPARE(b.stepIndexFor(QStringLiteral("layout")), 5);
        QCOMPARE(b.stepIndexFor(QStringLiteral("final")), 6);
        QCOMPARE(b.stepIndexFor(QStringLiteral("nope")), -1);
    }

    void progressAndResume()
    {
        WelcomeBackend b;
        b.reset();
        b.setUserName(QStringLiteral("Ada"));
        b.setLanguage(QStringLiteral("en"));
        b.setAppearance(QStringLiteral("light"));
        b.setAccent(QStringLiteral("#FF9F0A"));
        b.toggleApp(QStringLiteral("vlc"));
        b.setStep(4);
        // Reanudar: segunda instancia con el mismo HOME lee el .ini.
        WelcomeBackend r;
        QCOMPARE(r.step(), 4);
        QCOMPARE(r.userName(), QStringLiteral("Ada"));
        QCOMPARE(r.language(), QStringLiteral("en"));
        QCOMPARE(r.appearance(), QStringLiteral("light"));
        QCOMPARE(r.accent(), QStringLiteral("#FF9F0A"));
        QVERIFY(r.selectedApps().contains(QStringLiteral("vlc")));
        QVERIFY(!r.completed());
    }

    void skipAndFinish()
    {
        WelcomeBackend b;
        b.reset();
        QSignalSpy spy(&b, &WelcomeBackend::requestQuit);
        b.next();
        QCOMPARE(b.step(), 1);
        b.back();
        QCOMPARE(b.step(), 0);
        b.skip();
        QVERIFY(b.completed());
        QCOMPARE(spy.count(), 1);
        WelcomeBackend r;
        QVERIFY(r.completed());
        b.reset();
        WelcomeBackend z;
        QVERIFY(!z.completed());
        QCOMPARE(z.step(), 0);
    }

    void wifiSimulated()
    {
        WelcomeBackend b;
        b.reset();
        b.scanWifi();
        QVERIFY(!b.wifiNetworks().isEmpty());
        QVERIFY(!b.wifiStatus().isEmpty());
        b.connectWifi(QStringLiteral("Casa"), QStringLiteral("test"));
        QVERIFY(b.wifiStatus().contains(QStringLiteral("Casa")));
    }

    void layoutDefaultAndPersist()
    {
        WelcomeBackend b;
        b.reset();
        QCOMPARE(b.layout(), QStringLiteral("mac")); // Mac por defecto
        b.setLayout(QStringLiteral("windows"));
        QCOMPARE(b.layout(), QStringLiteral("windows"));
        b.setLayout(QStringLiteral("bogus")); // invalido: se ignora
        QCOMPARE(b.layout(), QStringLiteral("windows"));
        b.applyLayout(); // sim (NIMBUS_WELCOME_SIM=1): solo inis
        WelcomeBackend r; // reanuda: mismo HOME temporal
        QCOMPARE(r.layout(), QStringLiteral("windows"));
        const QString cfg = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
        QSettings w(cfg + QStringLiteral("/nimbus-welcome.ini"), QSettings::IniFormat);
        QCOMPARE(w.value(QStringLiteral("layout/name")).toString(), QStringLiteral("windows"));
        QSettings li(cfg + QStringLiteral("/nimbus-layout.ini"), QSettings::IniFormat);
        QCOMPARE(li.value(QStringLiteral("Layout/name")).toString(), QStringLiteral("windows"));
    }

    void appSelectionAndInstall()
    {
        WelcomeBackend b;
        b.reset();
        QCOMPARE(b.selectedApps().size(), 0);
        b.installApps(); // Sin apps seleccionadas
        QVERIFY(b.installStatus().contains(QStringLiteral("Elige al menos una")));
        QVERIFY(!b.isInstalling());

        // Seleccionar 3 apps (requisito de aceptación F9-T04: instala 3 apps)
        b.toggleApp(QStringLiteral("firefox"));
        b.toggleApp(QStringLiteral("vlc"));
        b.toggleApp(QStringLiteral("gimp"));
        QCOMPARE(b.selectedApps().size(), 3);
        QVERIFY(b.selectedApps().contains(QStringLiteral("firefox")));
        QVERIFY(b.selectedApps().contains(QStringLiteral("vlc")));
        QVERIFY(b.selectedApps().contains(QStringLiteral("gimp")));

        // Probar cancelación activa en segundo plano (F9-T04)
        qputenv("NIMBUS_WELCOME_SIM_PAUSE", "1");
        b.installApps();
        QVERIFY(b.isInstalling());
        QCOMPARE(b.installProgress(), 10);
        QVERIFY(b.installStatus().contains(QStringLiteral("Preparando")));

        b.cancelInstall();
        QVERIFY(!b.isInstalling());
        QCOMPARE(b.installStatus(), QStringLiteral("Instalación cancelada."));
        qunsetenv("NIMBUS_WELCOME_SIM_PAUSE");

        // Ejecutar instalación completa
        b.installApps();
        QCOMPARE(b.installProgress(), 100);
        QVERIFY(!b.isInstalling());
        QVERIFY(b.installStatus().contains(QStringLiteral("completada")));

        // Cancelación cuando ya está inactivo no corrompe el estado
        b.cancelInstall();
        QVERIFY(!b.isInstalling());
    }
};

QTEST_MAIN(TstWelcome)
#include "tst_welcome.moc"
