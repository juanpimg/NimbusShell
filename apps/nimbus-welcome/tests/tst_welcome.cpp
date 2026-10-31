// tst_welcome — progreso/persistencia del wizard F9-T02.
// Usa HOME temporal (el harness lo exporta); QSettings respeta
// XDG_CONFIG_HOME, así nunca toca el HOME real.
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QtTest>

#include "../welcomebackend.h"

class TstWelcome : public QObject {
    Q_OBJECT
private Q_SLOTS:
    void stepBounds()
    {
        WelcomeBackend b;
        b.reset();
        QCOMPARE(b.step(), 0);
        b.setStep(99);
        QCOMPARE(b.step(), 5);
        b.setStep(-3);
        QCOMPARE(b.step(), 0);
        QCOMPARE(b.stepCount(), 6);
        QCOMPARE(b.stepIndexFor(QStringLiteral("appearance")), 4);
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
};

QTEST_MAIN(TstWelcome)
#include "tst_welcome.moc"
